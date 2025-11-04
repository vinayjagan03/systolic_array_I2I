// -----------------------------------------------------------------------------
// Synthesizable FP32 multiplier (a*b), 2-stage pipeline
// - IEEE754 single (pragmatic): normals, +/-0; subnormals flushed to 0
// - Rounding: truncate
// -----------------------------------------------------------------------------
module fp32_mul #(
  parameter PIPE_STAGES = 2
)(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        valid_in,
  input  wire [31:0] a,
  input  wire [31:0] b,
  output wire        valid_out,
  output wire [31:0] y
);

  // Stage 1 regs
  reg         v1;
  reg         s1_sign;
  reg  [8:0]  s1_exp_sum;
  reg  [47:0] s1_prod;
  reg         s1_a_zero, s1_b_zero;

  // Stage 1
  always @(posedge clk or negedge rst_n) begin
    reg        a_sign, b_sign;
    reg [7:0]  a_exp,  b_exp;
    reg [22:0] a_frac, b_frac;
    reg [23:0] a_mant, b_mant;

    if (!rst_n) begin
      v1         <= 1'b0;
      s1_sign    <= 1'b0;
      s1_exp_sum <= 9'd0;
      s1_prod    <= 48'd0;
      s1_a_zero  <= 1'b1;
      s1_b_zero  <= 1'b1;
    end else begin
      v1      <= valid_in;

      a_sign  = a[31]; a_exp = a[30:23]; a_frac = a[22:0];
      b_sign  = b[31]; b_exp = b[30:23]; b_frac = b[22:0];

      s1_a_zero <= (a[30:0] == 31'd0);
      s1_b_zero <= (b[30:0] == 31'd0);

      // Flush subnormals to zero
      a_mant = (a_exp == 8'd0) ? 24'd0 : {1'b1, a_frac};
      b_mant = (b_exp == 8'd0) ? 24'd0 : {1'b1, b_frac};

      s1_sign    <= a_sign ^ b_sign;
      s1_exp_sum <= {1'b0,a_exp} + {1'b0,b_exp} - 9'd127; // bias adjust
      s1_prod    <= a_mant * b_mant; // 24x24 -> 48
    end
  end

  // Stage 2 regs
  reg         v2;
  reg [31:0]  y2;
  reg [31:0] out_word;
  reg [8:0]  exp_n;
  reg [22:0] frac_n;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v2 <= 1'b0;
      y2 <= 32'h0000_0000;
    end else begin
      v2 <= v1;
      y2 <= out_word;
    end
  end

  always_comb begin
      out_word = 32'h0000_0000;
      exp_n = 0;
      frac_n = 0;

      // Zero handling
      if (s1_a_zero || s1_b_zero || (s1_prod == 48'd0)) begin
        out_word = {s1_sign, 31'h0}; // +/-0
      end else begin
        exp_n = s1_exp_sum;
        // Normalize: product either 1.xx (bit46) or 2.xx (bit47)
        if (s1_prod[47]) begin
          exp_n  = exp_n + 9'd1;
          frac_n = s1_prod[46:24]; // truncate
        end else begin
          frac_n = s1_prod[45:23];
        end

        // Pack with simple overflow/underflow
        if (exp_n[8] || exp_n >= 9'd255)
          out_word = {s1_sign, 8'hFF, 23'h0};    // +/-Inf (overflow)
        else if (exp_n <= 9'd0)
          out_word = {s1_sign, 31'h0};           // underflow -> 0
        else
          out_word = {s1_sign, exp_n[7:0], frac_n};
      end
  end

  assign valid_out = v2;
  assign y         = y2;

endmodule
