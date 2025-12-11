`include "systolic_array_pkg.svh"

module tb_controller;
    parameter N = 4;
    parameter CLK_PERIOD = 10;

    logic clk, n_rst;
    // Address write signals
    logic AWVALID;
    word_t AWADDR;
    logic AWREADY;
    // Write signals
    logic WDVALID;
    word_t WDATA;
    logic WDREADY;
    // Address read signals
    logic ARVALID;
    word_t ARADDR;
    logic ARREADY;
    // Read signals
    logic RDREADY;
    logic RDVALID;
    word_t RDATA;
    // Scratchpad signals
    logic sc_read_en;
    logic sc_write_en;
    logic sc_addr;
    logic sc_ready;
    // sys array signals
    logic start_matmul;
    word_t input_addr, weight_addr, output_addr;
    logic matmul_finished;

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
    .sc_read_en         (sc_read_en),
    .sc_write_en        (sc_write_en),
    .sc_addr            (sc_addr),
    .sc_ready           (sc_ready),
    // sys array signals
    .start_matmul       (start_matmul),
    .input_addr              (input_addr),
    .weight_addr        (weight_addr),
    .output_addr              (output_addr),
    .matmul_finished    (matmul_finished)
);

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end


    // Test sequence
    initial begin
        // async reset
        @(posedge clk);
        n_rst = 0;
        AWVALID = 0;
        AWADDR = 0;
        WDVALID = 0;
        ARVALID = 0;
        ARADDR = 0;
        RDREADY = 0;
        sc_ready = 0;
        matmul_finished = 0;

        // Send data to scratchpad
        @(posedge clk);
        n_rst = 1;
        AWVALID = 1'b1;
        AWADDR = 32'h8;
        @(posedge clk);
        AWVALID = 1'b0;
        AWADDR = 32'h0;
        WDVALID = 1'b1;
        WDATA = 32'h5678;
        @(posedge clk);
        WDVALID = 1'b0;
        WDATA = 32'h0;
        @(posedge clk);
        $finish;
    end
endmodule