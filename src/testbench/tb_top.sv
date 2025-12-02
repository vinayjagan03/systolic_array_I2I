`timescale 1ns/1ps
`include "systolic_array_pkg.svh"

module tb_top;

    localparam N = 4;

    // ------------------------------------------
    // Clock / Reset
    // ------------------------------------------
    logic clk, n_rst;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    logic AWVALID;
    logic [31:0] AWADDR;
    logic AWREADY;
    logic WDVALID;
    logic [31:0] WDATA;
    logic WDREADY;
    logic ARVALID;
    logic [31:0] ARADDR;
    logic ARREADY;
    logic RDREADY;
    logic RDVALID;
    logic [31:0] RDATA;

    logic [N-1:0][31:0] sc_x_queue;
    logic [N-1:0][31:0] sc_w_queue;
    logic [N-1:0] sc_valid_queue;
    logic [N-1:0] sc_valid_write;
    logic [N-1:0][31:0] sc_write_queue;
    logic [N-1:0][31:0] sc_write_data;
    logic [N-1:0][31:0] sc_x_data;
    logic [N-1:0][31:0] sc_w_data;   


    top #(
    .N                 (4)
) DUT (
    .clk               (clk),
    .n_rst             (n_rst),
    // Address write signals
    .AWVALID           (AWVALID),
    .AWADDR            (AWADDR),
    .AWREADY           (AWREADY),
    // Write signals
    .WDVALID           (WDVALID),
    .WDATA             (WDATA),
    .WDREADY           (WDREADY),
    // Address read signals
    .ARVALID           (ARVALID),
    .ARADDR            (ARADDR),
    .ARREADY           (ARREADY),
    // Read signals
    .RDREADY           (RDREADY),
    .RDVALID           (RDVALID),
    .RDATA             (RDATA),
    .sc_x_queue        (sc_x_queue),
    .sc_w_queue        (sc_w_queue),
    .sc_valid_queue    (sc_valid_queue),
    .sc_valid_write    (sc_valid_write),
    .sc_write_queue    (sc_write_queue),
    .sc_write_data     (sc_write_data),
    .sc_x_data         (sc_x_data),
    .sc_w_data         (sc_w_data)
);

    word_t sc [logic[31:0]];    
    logic finished;
    int counter = 0;

    initial begin
        n_rst = 0;
        AWVALID = 0;
        AWADDR = 0;
        WDVALID = 0;
        WDATA = 0;
        ARVALID = 0;
        ARADDR = 0;
        RDREADY = 0;
        sc_x_data = 0;
        sc_w_data = 0;
        finished = 0;
        counter = 0;


        @(posedge clk);
        n_rst = 1;

        fork
            begin
                while (!finished) begin
                    @(posedge clk);
                    @(negedge clk);
                    for (int i = 0; i < N; i++) begin
                        if (sc_valid_queue[i]) begin
                            //$display("Reading Data[%0d]: %0d", sc_x_queue[i], $bitstoshortreal(sc[sc_x_queue[i]]));
                            sc_x_data[i] = sc[sc_x_queue[i]];
                            sc_w_data[i] = sc[sc_w_queue[i]];
                        end else begin
                            sc_x_data[i] = 0;
                            sc_w_data[i] = 0;
                        end
                        if (sc_valid_write[i]) begin
                            $display("Writing Data[%0d]: %0d", sc_write_queue[i], $bitstoshortreal(sc_write_data[i]));
                            sc[sc_write_queue[i]] = sc_write_data[i];
                        end
                    end
                end
            end
            begin
                // Write input matrix
                @(posedge clk);
                AWVALID = 1;
                AWADDR = 32'h00000000;
                WDVALID = 1;
                for (int i = 0; i < 16; i++) begin
                    @(posedge clk);
                    WDATA = $shortrealtobits(shortreal'(i + 1));
                    AWADDR = 32'h00000000 + i;
                    @(posedge clk);
                end
                AWVALID = 0;
                WDVALID = 0;
                WDATA = 0;

                @(posedge clk);
                // Write weight matrix (identity)
                AWVALID = 1;
                AWADDR = 32'h00000F00;
                for (int r = 0; r < N; r++) begin
                    for (int c = 0; c < N; c++) begin
                        @(posedge clk);
                        AWADDR = 32'h00000F00 + r*N + c;
                        WDATA = (r == c) ? $shortrealtobits(shortreal'(1)) : $shortrealtobits(shortreal'(0));
                        @(posedge clk);
                    end
                end
                AWVALID = 0;
                WDVALID = 0;
                WDATA = 0;

                // Setup matmul
                @(posedge clk);
                AWVALID = 1;
                AWADDR = 32'hF0000; // input addr
                WDATA = 32'h00000000;
                @(posedge clk);
                @(posedge clk);
                AWADDR = 32'hF0001; // weight addr
                WDATA = 32'h00000F00;
                @(posedge clk);
                @(posedge clk);
                AWADDR = 32'hF0003; // output addr
                WDATA = 32'h0000F000;
                @(posedge clk);
                @(posedge clk);
                AWVALID = 0;
                WDATA = 0;

                // Start matmul
                @(posedge clk);
                AWVALID = 1;
                AWADDR = 32'h100000;
                @(posedge clk);

                while (WDREADY == 0) begin
                    counter++;
                    @(posedge clk);
            //         if (counter % 6 != 0 && (counter * 6) >= 2*N + N-1) continue;
            //                     $write("\nx: ");
            // for (int j = 0; j < N*N; j++) begin
            //     if (j%N == 0) begin
            //         $display("");
            //     end
            //     $write("%08f ", $bitstoshortreal(DUT.u_systolic_array_top.sys_array.x[j / N][j % N]));
            // end
            // $write("\nw: ");
            // for (int j = 0; j < N*N; j++) begin
            //     if (j%N == 0) begin
            //         $display("");
            //     end
            //     $write("%08f ", $bitstoshortreal(DUT.u_systolic_array_top.sys_array.w[j / N][j % N]));
            // end
            // $write("\npsum: ");
            // for (int j = 0; j < N*N; j++) begin
            //     if (j%N == 0) begin
            //         $display("");
            //     end
            //     $write("%08f ", $bitstoshortreal(DUT.u_systolic_array_top.sys_array.psum[j / N][j % N]));
            // end
            // $display("");
                end
                AWVALID = 0;

                // Read output matrix
                @(posedge clk);
                ARVALID = 1;
                ARADDR = 32'h0000F000;
                for (int i = 0; i < 16; i++) begin
                    @(posedge clk);
                    ARADDR = 32'h0000F000 + i;
                    @(negedge clk);
                    $display("Output Data[%0d]: %0d", ARADDR, $bitstoshortreal(RDATA));
                    @(posedge clk);
                    ARADDR = 32'h0000F000 + i + 1;
                end
                ARVALID = 0;
                finished = 1;
            end
        join
        $finish;
    end


endmodule