// Code your design here
// -----------------------------------------------------------------------------
// Synthesizable FP32 MAC: y = a*b + c  OR  acc <= acc + a*b (use_acc=1)
// Pipes: mul=2, add=3  => ~5 cycles latency
// -----------------------------------------------------------------------------
`include "fp32_mul.sv"
`include "fp32_add.sv"
module fp32_mac (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        valid_in,
  output wire        ready_in,   // always 1
  input  wire [31:0] a,
  input  wire [31:0] b,
  input  wire [31:0] c,
  input  wire        use_acc,
  input  wire        clr_acc,
  output wire        valid_out,
  output wire [31:0] y
);

  assign ready_in = 1'b1;

  // Multiply stage
  wire        m_vld;
  wire [31:0] m_res;

  fp32_mul #(.PIPE_STAGES(2)) U_MUL (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (valid_in),
    .a         (a),
    .b         (b),
    .valid_out (m_vld),
    .y         (m_res)
  );

  // Accumulator
  reg [31:0] acc_q;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      acc_q <= 32'h0000_0000;
    else if (clr_acc)
      acc_q <= 32'h0000_0000;
    else if (use_acc && valid_out)
      acc_q <= y; // update with adder result when it becomes valid
  end

  // Select adder inputs
  reg  [31:0] add_lhs, add_rhs;
  wire        add_vin = m_vld;

  always @* begin
    if (use_acc) begin
      add_lhs = acc_q;
      add_rhs = m_res;
    end else begin
      add_lhs = m_res;
      add_rhs = c;
    end
  end

  // Adder
  wire        a_vld;
  wire [31:0] add_res;

  fp32_add #(.PIPE_STAGES(3)) U_ADD (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (add_vin),
    .a         (add_lhs),
    .b         (add_rhs),
    .valid_out (a_vld),
    .y         (add_res)
  );

  assign valid_out = a_vld;
  assign y         = add_res;

endmodule
