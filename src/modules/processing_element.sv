`include "systolic_array_pkg.svh"

module processing_element #(parameter N=64)(
    input logic clk, n_rst,
    input word_t x_i,
    input word_t w_i,
    input logic input_start,
    output word_t partial_sum,
    output word_t x_o,
    output word_t w_o,
    output logic data_ready,
    output logic stall
);

    word_t fp32_result, next_fp32_result;
    logic fp32_ready;
    word_t psum_reg, next_psum_reg;

    word_t count, next_count;

    fp32_mac u_fp32_mac (
        .clk          (clk),
        .rst_n        (n_rst),
        .valid_in     (input_start),
        // always 1
        .a            (x_i),
        .b            (w_i),
        .c            (0),
        .x_i          (x_i),
        .w_i          (w_i),
        .use_acc      (1'b1),
        .clr_acc      (1'b0),
        .valid_out    (fp32_ready),
        .y            (next_fp32_result)
        );

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            psum_reg <= '0;
            fp32_result <= 0;
            count <= 0;
            x_o <= '0;
            w_o <= '0;
        end else begin
            psum_reg <= next_psum_reg;
            fp32_result <= (fp32_ready) ? next_fp32_result : fp32_result;
            count <= next_count;
            x_o <= x_i;
            w_o <= w_i;
        end
    end

    always_comb begin
        partial_sum = fp32_result;
        data_ready = 1'b1;
        stall = 0;
        next_psum_reg = psum_reg;
        next_count = count + 1;
    end


endmodule