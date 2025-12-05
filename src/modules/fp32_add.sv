module fp32_add (
  input  logic        clk,       // unused (combinational core)
  input  logic        rst_n,     // unused (combinational core)
  input  logic        valid_in,
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [31:0] x_i, w_i,
  output logic [31:0] x_o, w_o,
  output logic        valid_out,
  output logic [31:0] y
);

  // IEEE 754 single precision parameters
  localparam int EXP_BITS  = 8;
  localparam int FRAC_BITS = 23;
  localparam int BIAS      = 127;

  // Unpacked fields
  logic                 sign_a, sign_b;
  logic [EXP_BITS-1:0]  exp_a,  exp_b;
  logic [FRAC_BITS-1:0] frac_a, frac_b;

  // Result fields
  logic                 sign_res;
  logic [EXP_BITS-1:0]  exp_res;
  logic [FRAC_BITS-1:0] frac_res;

  // Special-case flags
  logic is_zero_a, is_zero_b;
  logic is_inf_a,  is_inf_b;
  logic is_nan_a,  is_nan_b;

  // Mantissas and extended mantissas
  logic [23:0] mant_a, mant_b;
  logic [27:0] mant_a_ext, mant_b_ext;

  // Effective exponents
  logic [8:0]  exp_a_eff, exp_b_eff;

  // Bigger/smaller selection
  logic        a_bigger;
  logic [8:0]  exp_big, exp_sml;
  logic [27:0] mant_big_ext, mant_sml_ext;
  logic        sign_big, sign_sml;

  // Alignment / shift
  logic [4:0]  shift_amt;
  logic [27:0] mant_sml_shifted;
  logic        sticky;

  // Add/sub
  logic [27:0] mant_sum_ext;
  logic        same_sign;

  // Normalization
  logic [27:0] mant_norm_ext;
  logic [8:0]  exp_norm;

  // Rounding
  logic [23:0] mant_round;
  logic        guard, round_bit, sticky_bit, round_inc;

  always_comb begin
    // Default passthroughs / control
    x_o       = x_i;
    w_o       = w_i;
    valid_out = valid_in;

    // Unpack operands
    sign_a = a[31];
    exp_a  = a[30:23];
    frac_a = a[22:0];

    sign_b = b[31];
    exp_b  = b[30:23];
    frac_b = b[22:0];

    // Detect specials
    is_zero_a = (exp_a == 8'd0) && (frac_a == 23'd0);
    is_zero_b = (exp_b == 8'd0) && (frac_b == 23'd0);

    is_inf_a  = (exp_a == 8'hFF) && (frac_a == 23'd0);
    is_inf_b  = (exp_b == 8'hFF) && (frac_b == 23'd0);

    is_nan_a  = (exp_a == 8'hFF) && (frac_a != 23'd0);
    is_nan_b  = (exp_b == 8'hFF) && (frac_b != 23'd0);

    // Default result - quiet NaN
    sign_res = 1'b0;
    exp_res  = 8'hFF;
    frac_res = 23'h400000; // qNaN payload

    // ---------------- Special cases ----------------
    if (is_nan_a || is_nan_b) begin
      // NaN propagates (already set)
      sign_res = 1'b0;
      exp_res  = 8'hFF;
      frac_res = 23'h400000;
    end else if (is_inf_a && is_inf_b) begin
      if (sign_a == sign_b) begin
        // inf + inf (same sign)
        sign_res = sign_a;
        exp_res  = 8'hFF;
        frac_res = 23'd0;
      end else begin
        // +inf + -inf => NaN
        sign_res = 1'b0;
        exp_res  = 8'hFF;
        frac_res = 23'h400000;
      end
    end else if (is_inf_a) begin
      sign_res = sign_a;
      exp_res  = 8'hFF;
      frac_res = 23'd0;
    end else if (is_inf_b) begin
      sign_res = sign_b;
      exp_res  = 8'hFF;
      frac_res = 23'd0;
    end else if (is_zero_a && is_zero_b) begin
      // Both zero (choose a sign convention; here AND)
      sign_res = sign_a & sign_b;
      exp_res  = 8'd0;
      frac_res = 23'd0;
    end else begin
      // ---------------- Normal / subnormal path ----------------

      // Build mantissas with implicit bit
      mant_a = (exp_a == 8'd0) ? {1'b0, frac_a} : {1'b1, frac_a};
      mant_b = (exp_b == 8'd0) ? {1'b0, frac_b} : {1'b1, frac_b};

      // Extend mantissas to include GRS bits
      mant_a_ext = {mant_a, 3'b000};
      mant_b_ext = {mant_b, 3'b000};

      // Effective exponents (subnormal => exponent 1)
      exp_a_eff = (exp_a == 8'd0) ? 9'd1 : {1'b0, exp_a};
      exp_b_eff = (exp_b == 8'd0) ? 9'd1 : {1'b0, exp_b};

      // Choose bigger operand (by exponent, then mantissa)
      if ( (exp_a_eff > exp_b_eff) ||
           ((exp_a_eff == exp_b_eff) && (mant_a_ext >= mant_b_ext)) ) begin
        a_bigger     = 1'b1;
        exp_big      = exp_a_eff;
        exp_sml      = exp_b_eff;
        mant_big_ext = mant_a_ext;
        mant_sml_ext = mant_b_ext;
        sign_big     = sign_a;
        sign_sml     = sign_b;
      end else begin
        a_bigger     = 1'b0;
        exp_big      = exp_b_eff;
        exp_sml      = exp_a_eff;
        mant_big_ext = mant_b_ext;
        mant_sml_ext = mant_a_ext;
        sign_big     = sign_b;
        sign_sml     = sign_a;
      end

      // Align smaller mantissa
      shift_amt = (exp_big > exp_sml) ? (exp_big - exp_sml) : 5'd0;

      if (shift_amt == 0) begin
        mant_sml_shifted = mant_sml_ext;
        sticky           = 1'b0;
      end else if (shift_amt >= 5'd27) begin
        mant_sml_shifted = 28'd0;
        sticky           = (mant_sml_ext != 28'd0);
      end else begin
        // Shift-right with sticky
        logic [27:0] tmp_shifted;
        logic [27:0] tmp_dropped;

        tmp_shifted       = mant_sml_ext >> shift_amt;
        tmp_dropped       = mant_sml_ext & ((28'h1 << shift_amt) - 1);
        mant_sml_shifted  = tmp_shifted;
        sticky            = (tmp_dropped != 28'd0);
      end

      // Merge sticky into LSB
      if (sticky)
        mant_sml_shifted[0] = 1'b1;

      // Add or subtract
      same_sign = (sign_big == sign_sml);
      if (same_sign) begin
        mant_sum_ext = mant_big_ext + mant_sml_shifted;
        sign_res     = sign_big;
      end else begin
        mant_sum_ext = mant_big_ext - mant_sml_shifted;
        sign_res     = sign_big; // sign of larger magnitude
      end

      // Zero result after subtraction
      if (mant_sum_ext == 28'd0) begin
        sign_res = 1'b0;
        exp_res  = 8'd0;
        frac_res = 23'd0;
      end else begin
        // --------------- Normalization ---------------
        mant_norm_ext = mant_sum_ext;
        exp_norm      = exp_big;

        // Possible overflow when adding same-sign
        if (same_sign && mant_norm_ext[27]) begin
          mant_norm_ext = mant_norm_ext >> 1;
          exp_norm      = exp_norm + 9'd1;
        end else begin
          // Normalize left so that leading 1 is at bit 26
          while ( (mant_norm_ext[26] == 1'b0) &&
                  (exp_norm > 0) &&
                  (mant_norm_ext != 28'd0) ) begin
            mant_norm_ext = mant_norm_ext << 1;
            exp_norm      = exp_norm - 9'd1;
          end
        end

        // --------------- Rounding: round to nearest-even ---------------
        mant_round = mant_norm_ext[26:3];  // 1.xxx (24 bits)
        guard      = mant_norm_ext[2];
        round_bit  = mant_norm_ext[1];
        sticky_bit = mant_norm_ext[0];

        // Increment if guard==1 and (round_bit or sticky_bit or LSB is 1)
        round_inc = guard && (round_bit || sticky_bit || mant_round[0]);

        if (round_inc) begin
          mant_round = mant_round + 24'd1;
          // Handle mantissa overflow on rounding
          if (mant_round == 24'h1000000) begin
            // 1.000...0 -> shift and increment exponent
            mant_round = mant_round >> 1;
            exp_norm   = exp_norm + 9'd1;
          end
        end

        // --------------- Pack result, check overflow/underflow ---------------
        if (exp_norm >= 9'd255) begin
          // Overflow => infinity
          exp_res  = 8'hFF;
          frac_res = 23'd0;
        end else if (exp_norm <= 9'd0) begin
          // Underflow: flush to zero (simplified)
          exp_res  = 8'd0;
          frac_res = 23'd0;
          // sign_res unchanged
        end else begin
          exp_res  = exp_norm[7:0];
          frac_res = mant_round[22:0]; // drop implicit 1
        end
      end
    end

    // Pack final result
    y = {sign_res, exp_res, frac_res};
  end

endmodule
