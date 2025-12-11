`timescale 1ns/1ps
`include "systolic_array_pkg.svh"

module tb_new_working;

    localparam int N  = 4;

    // ------------------------------------------
    // Clock / Reset
    // ------------------------------------------
    logic clk, n_rst;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    logic [31:0] x_addr;
    logic [31:0] w_addr;
    logic [N-1:0][31:0] sc_x_queue;
    logic [N-1:0][31:0] sc_w_queue;
    logic [N-1:0] sc_valid_queue;
    word_t [N-1:0] sc_x_data;
    word_t [N-1:0] sc_w_data;
    logic start_mul;
    logic stall_mul;

    systolic_array_top #(
    .N                 (N)
) DUT (
    .clk               (clk),
    .n_rst             (n_rst),
    .x_addr            (x_addr),
    .w_addr            (w_addr),
    .sc_x_queue        (sc_x_queue),
    .sc_w_queue        (sc_w_queue),
    .sc_valid_queue    (sc_valid_queue),
    .sc_x_data         (sc_x_data),
    .sc_w_data         (sc_w_data),
    .start_mul         (start_mul),
    .stall_mul         (stall_mul)
);

    word_t sc [logic[31:0]];

    initial begin
        n_rst = 0;
        x_addr = 0;
        w_addr = 0;
        sc_x_data = 0;
        sc_w_data = 0;
        start_mul = 0;

        @(posedge clk);
        n_rst = 1;

        x_addr = 32'h00000000;
        w_addr = 32'h00000F00;

        /*
        1 2 3 4
        5 6 7 8
        9 10 11 12
        13 14 15 16
        */
        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                sc[x_addr + r*N + c] = $shortrealtobits(shortreal'(r * N + c + 1));
                sc[w_addr + r*N + c] = (r == c) ? $shortrealtobits(shortreal'(1)) : $shortrealtobits(shortreal'(0));
            end
        end

        @(posedge clk);
        start_mul = 1'b1;
        @(posedge clk);
        for (int i = 0; i < N; i++) begin
            if (sc_valid_queue[i]) begin
                sc_x_data[i] = sc[sc_x_queue[i]];
                sc_w_data[i] = sc[sc_w_queue[i]];
            end else begin
                sc_x_data[i] = 0;
                sc_w_data[i] = 0;
            end
        end

        @(negedge clk);
        while (stall_mul) begin
            for (int i = 0; i < N; i++) begin
                if (sc_valid_queue[i]) begin
                    sc_x_data[i] = sc[sc_x_queue[i]];
                    sc_w_data[i] = sc[sc_w_queue[i]];
                end else begin
                    sc_x_data[i] = 0;
                    sc_w_data[i] = 0;
                end
            end
            if (DUT.next_state == 1 && DUT.state == 2) begin
            $display("pe 0 state: %d", DUT.state);
            $write("\nx: ");
            for (int j = 0; j < N*N; j++) begin
                if (j%N == 0) begin
                    $display("");
                end
                $write("%08f ", $bitstoshortreal(DUT.sys_array.x[j / N][j % N]));
            end
            $write("\nw: ");
            for (int j = 0; j < N*N; j++) begin
                if (j%N == 0) begin
                    $display("");
                end
                $write("%08f ", $bitstoshortreal(DUT.sys_array.w[j / N][j % N]));
            end
            $write("\npsum: ");
            for (int j = 0; j < N*N; j++) begin
                if (j%N == 0) begin
                    $display("");
                end
                $write("%08f ", $bitstoshortreal(DUT.sys_array.psum[j / N][j % N]));
            end
            $display("");
            end
            @(posedge clk);
            @(negedge clk);
        end
        start_mul = 1'b0;

        $display("at finish stage");
        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                $write("%08f ", $bitstoshortreal(DUT.sys_array.psum[r][c]));
            end
            $display();
        end

    $finish;
    end


endmodule