`include "systolic_array_pkg.svh"

module fp32_stage_mul_setup (
    input logic clk, n_rst,
    input logic valid_i,
    input word_t a,
    input word_t b,
    output logic [22:0] mantissa_a,
    output logic [22:0] mantissa_b,
    output logic [9:0] exponent_sum,
    output logic sign,
    output logic valid_o
);

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            mantissa_a <= 0;
            mantissa_b <= 0;
            exponent_sum <= 0;
            sign <= 0;
            valid_o <= 0;
        end else begin
            mantissa_a <= a.mantissa;
            mantissa_b <= b.mantissa;
            exponent_sum <= a.exponent + b.exponent;
            sign <= a.sign ^ b.sign;
            valid_o <= valid_i;
        end
    end

endmodule