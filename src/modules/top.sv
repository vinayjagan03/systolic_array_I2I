`include "systolic_array_pkg.svh"

module top #(parameter N = 64)(
    input logic clk, n_rst,
    // Address write signals
    input logic AWVALID,
    input word_t AWADDR,
    output logic AWREADY,
    // Write signals
    input logic WDVALID,
    input word_t WDATA,
    output logic WDREADY,
    // Address read signals
    input logic ARVALID,
    input word_t ARADDR,
    output logic ARREADY,
    // Read signals
    input logic RDREADY,
    output logic RDVALID,
    output word_t RDATA,

    output logic [N-1:0][31:0] sc_x_queue,
    output logic [N-1:0][31:0] sc_w_queue,
    output logic [N-1:0] sc_valid_queue,
    output logic [N-1:0] sc_valid_write,
    output logic [N-1:0][31:0] sc_write_queue,
    output logic [N-1:0][31:0] sc_write_data,
    input word_t [N-1:0] sc_x_data,
    input word_t [N-1:0] sc_w_data    
);
    logic controller_sc_read_en;
    logic controller_sc_write_en;
    logic [31:0] controller_sc_addr;
    logic [31:0] controller_sc_in;
    logic [31:0] controller_sc_out;

    logic start_matmul;
    logic [31:0] input_addr;
    logic [31:0] weight_addr;
    logic stall_mul;
    logic [31:0] output_addr;

    controller u_controller (
    .clk                (clk),
    .n_rst              (n_rst),
    // Address write signals
    .AWVALID            (AWVALID),
    .AWADDR             (AWADDR),
    .AWREADY            (AWREADY),
    // Write signals
    .WDVALID            (WDVALID),
    .WDATA              (WDATA),
    .WDREADY            (WDREADY),
    // Address read signals
    .ARVALID            (ARVALID),
    .ARADDR             (ARADDR),
    .ARREADY            (ARREADY),
    // Read signals
    .RDREADY            (RDREADY),
    .RDVALID            (RDVALID),
    .RDATA              (RDATA),
    // Scratchpad signals
    .sc_read_en         (controller_sc_read_en),
    .sc_write_en        (controller_sc_write_en),
    .sc_data_in         (controller_sc_in),
    .sc_data_out        (controller_sc_out),
    .sc_addr            (controller_sc_addr),
    .sc_ready           (1'b1),
    // sys array signals
    .start_matmul       (start_matmul),
    .input_addr              (input_addr),
    .weight_addr        (weight_addr),
    .output_addr              (output_addr),
    .matmul_finished    (!stall_mul)
);

systolic_array_top #(
    .N                         (N)
) u_systolic_array_top (
    .clk                       (clk),
    .n_rst                     (n_rst),
    .x_addr                    (input_addr),
    .w_addr                    (weight_addr),
    .sc_x_queue                (sc_x_queue),
    .sc_w_queue                (sc_w_queue),
    .sc_valid_queue            (sc_valid_queue),
    .sc_valid_write            (sc_valid_write),
    .sc_write_queue            (sc_write_queue),
    .sc_write_data             (sc_write_data),
    .sc_x_data                 (sc_x_data),
    .sc_w_data                 (sc_w_data),
    .start_mul                 (start_matmul),
    .stall_mul                 (stall_mul),
    .controller_sc_read_en     (controller_sc_read_en),
    .controller_sc_write_en    (controller_sc_write_en),
    .controller_sc_addr        (controller_sc_addr),
    .controller_sc_out         (controller_sc_out),
    .controller_sc_in          (controller_sc_in)
);

endmodule