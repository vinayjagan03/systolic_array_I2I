// -----------------------------------------------------------------------------
// Synthesizable FP32 adder (y=a+b), 3-stage pipeline
// - Normals, +/-0; subnormals flushed to 0; truncate rounding
// -----------------------------------------------------------------------------
module fp32_add #(
  parameter PIPE_STAGES = 3
)(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        valid_in,
  input  wire [31:0] a,
  input  wire [31:0] b,
  output wire        valid_out,
  output wire [31:0] y
);

  // ---------- Stage 1: unpack, choose big/small, align ----------
  reg        v1;
  reg        s1_sign_big, s1_sign_sml;
  reg [7:0]  s1_exp_big,  s1_exp_sml;
  reg [27:0] s1_mant_big, s1_mant_sml; // 24 + 4 guard bits
  reg        s1_subtract;

  always @(posedge clk or negedge rst_n) begin
    reg        a_s, b_s, swap;
    reg [7:0]  a_e, b_e, exp_diff;
    reg [22:0] a_f, b_f;
    reg [23:0] M_a, M_b;
    reg [27:0] M_big_28, M_sml_28;
    reg [7:0]  E_big, E_sml;
    reg        S_big, S_sml;

    if (!rst_n) begin
      v1            <= 1'b0;
      s1_sign_big   <= 1'b0; s1_sign_sml <= 1'b0;
      s1_exp_big    <= 8'd0; s1_exp_sml  <= 8'd0;
      s1_mant_big   <= 28'd0; s1_mant_sml<= 28'd0;
      s1_subtract   <= 1'b0;
    end else begin
      v1 <= valid_in;

      a_s = a[31]; a_e = a[30:23]; a_f = a[22:0];
      b_s = b[31]; b_e = b[30:23]; b_f = b[22:0];

      // Flush subnormals to 0, otherwise add hidden 1
      M_a = (a_e == 8'd0) ? 24'd0 : {1'b1, a_f};
      M_b = (b_e == 8'd0) ? 24'd0 : {1'b1, b_f};

      // Choose bigger magnitude (by exponent then mantissa)
      swap = (b_e > a_e) || ((b_e == a_e) && (b_f > a_f));

      S_big = swap ? b_s : a_s;
      E_big = swap ? b_e : a_e;
      M_big_28 = { (swap ? M_b : M_a), 4'b0 };

      S_sml = swap ? a_s : b_s;
      E_sml = swap ? a_e : b_e;
      // align small
      exp_diff = (E_big >= E_sml) ? (E_big - E_sml) : 8'd0;
      if (exp_diff >= 8'd27)  M_sml_28 = 28'd0;
      else                    M_sml_28 = ({ (swap ? M_a : M_b), 4'b0 } >> exp_diff);

      s1_sign_big <= S_big;
      s1_exp_big  <= E_big;
      s1_mant_big <= M_big_28;
      s1_sign_sml <= S_sml;
      s1_exp_sml  <= E_sml;
      s1_mant_sml <= M_sml_28;
      s1_subtract <= (S_big ^ S_sml);
    end
  end

  // ---------- Stage 2: add/sub mantissas ----------
  reg        v2;
  reg        s2_sign;
  reg [7:0]  s2_exp;
  reg [28:0] s2_mant; // one extra bit for carry/borrow
  reg        s2_is_zero;

  always @(posedge clk or negedge rst_n) begin
    reg [28:0] mant_res;
    if (!rst_n) begin
      v2        <= 1'b0;
      s2_sign   <= 1'b0;
      s2_exp    <= 8'd0;
      s2_mant   <= 29'd0;
      s2_is_zero<= 1'b0;
    end else begin
      v2      <= v1;
      s2_sign <= s1_sign_big;
      s2_exp  <= s1_exp_big;

      if (s1_subtract)
        mant_res = {1'b0, s1_mant_big} - {1'b0, s1_mant_sml};
      else
        mant_res = {1'b0, s1_mant_big} + {1'b0, s1_mant_sml};

      s2_mant    <= mant_res;
      s2_is_zero <= (mant_res == 29'd0);
    end
  end

  // ---------- Stage 3: normalize & pack ----------
  reg        v3;
  reg [31:0] y3;

  // leading-zero count for 29-bit value (simple loop; synthesizes as priority enc)
function automatic [4:0] lz29;
  input [28:0] x;
  begin
    if (x[28]) begin
      lz29 = 5'd0;    // MSB already 1 → no leading zeros
    end
    else begin
      lz29 = 5'd29;   // default: all zero
      for_loop_end: for (int i = 27; i >= 0; i = i-1) begin
        if (x[i]) begin
          lz29 = 5'(28 - i); // # of zeros before first '1'
          break;
          //disable for_loop_end; // exit early once found
        end
      end
    end
  end
endfunction

    reg [31:0] out_word;
    reg [28:0] mant;
    reg [7:0]  expn;
    reg [22:0] frac;
    reg [4:0]  lz;


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v3 <= 1'b0;
      y3 <= 32'h0000_0000;
    end else begin
      v3 <= v2;
      y3 <= out_word;
    end
  end

  always_comb begin
      out_word = 32'h0000_0000;
      mant = 0;
      expn = 0;
      lz = 0;
      frac = 0;

      if (s2_is_zero) begin
        out_word = {s2_sign, 31'h0};
      end else begin
        mant = s2_mant;
        expn = s2_exp;

        // If carry into bit28: shift right 1, bump exp
        if (mant[28]) begin
          mant = mant >> 1;
          expn = expn + 8'd1;
        end else begin
          // Normalize left if needed
          if (mant[27:24] == 4'b0000) begin
            lz = lz29(mant);
            if (lz < 5'd29) begin
              mant = mant << lz;
              if (expn > lz) expn = expn - lz; else expn = 8'd0;
            end else begin
              mant = 29'd0;
              expn = 8'd0;
            end
          end
        end

        frac = mant[26:4]; // truncate

        if (expn >= 8'hFF)
          out_word = {s2_sign, 8'hFF, 23'h0};
        else if (expn == 8'd0)
          out_word = {s2_sign, 31'h0};
        else
          out_word = {s2_sign, expn, frac};
      end

  end

  assign valid_out = v3;
  assign y         = y3;

endmodule
