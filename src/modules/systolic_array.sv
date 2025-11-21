`include "systolic_array_pkg.svh"

module systolic_array #(parameter N=4) (
    input logic clk, n_rst,
    input logic start,
    input word_t [N-1:0] x_in,
    input word_t [N-1:0] w_in,
    input logic [$clog2(N)-1:0] y_index,
    output word_t [N-1:0] y_out,
    output logic stall
);

    word_t[N-1:0][N-1:0] x;
    word_t[N-1:0][N-1:0] w;
    word_t[N-1:0][N-1:0] psum;
    logic [N-1:0][N-1:0] data_ready;
    logic [N-1:0][N-1:0] pe_stall;
    word_t [N-1:0][N-1:0] count;

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                processing_element #(.N(N)) pe (
                    .clk(clk),
                    .n_rst(n_rst),
                    .x_i(j == 0 ? x_in[i] : x[i][j - 1]),
                    .w_i(i == 0 ? w_in[j] : w[i - 1][j]),
                    .input_start(i == 0 || j == 0 ? start : data_ready[i][j - 1] && data_ready[i - 1][j]),
                    .partial_sum(psum[i][j]),
                    .x_o(x[i][j]),
                    .w_o(w[i][j]),
                    .data_ready(data_ready[i][j]),
                    .stall(pe_stall[i][j])
                );
            end
        end
    endgenerate

    assign y_out = psum[y_index];
    assign stall = |pe_stall[0];

endmodule
