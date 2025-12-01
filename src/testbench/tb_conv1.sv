`timescale 1ns/1ps
`include "systolic_array_pkg.svh"
`include "alexnet_conv1_meta.svh"
import alexnet_conv1_meta::*;
// from alexnet_conv1_meta.svh
localparam int M    = CONV1_IM2COL_M;     // 3136
localparam int K    = CONV1_IM2COL_K;     // 363
localparam int COUT = CONV1_WEIGHTS_COUT; // 96
localparam int N    = SA_N;               // 64 (systolic array dimension)

// --------- Global buffers in TB ---------

// im2col input T: M x K
word_t T   [M][K];

// weights W: K x COUT
word_t W   [K][COUT];

// output Y: M x COUT (accumulated over K tiles)
shortreal Y [M][COUT];   // store as float for w

module tb_conv1;

    localparam int N  = 4;

    // ------------------------------------------
    // Clock / Reset
    // ------------------------------------------
    logic clk, n_rst;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------
    // DUT interface
    // ------------------------------------------

    logic [31:0] x_addr;
    logic [31:0] w_addr;

    logic [N-1:0][31:0] sc_x_queue;
    logic [N-1:0][31:0] sc_w_queue;
    logic [N-1:0]       sc_valid_queue;
    word_t [N-1:0]      sc_x_data;
    word_t [N-1:0]      sc_w_data;
    logic               start_mul;
    logic               stall_mul;

    // Instantiate DUT exactly like tb_new_working
    systolic_array_top #(
        .N (N)
    ) DUT (
        .clk            (clk),
        .n_rst          (n_rst),
        .x_addr         (x_addr),
        .w_addr         (w_addr),
        .sc_x_queue     (sc_x_queue),
        .sc_w_queue     (sc_w_queue),
        .sc_valid_queue (sc_valid_queue),
        .sc_x_data      (sc_x_data),
        .sc_w_data      (sc_w_data),
        .start_mul      (start_mul),
        .stall_mul      (stall_mul)
    );

    // ------------------------------------------
    // Simple scratchpad model
    // ------------------------------------------
    word_t sc [logic[31:0]];

    // ------------------------------------------
    // Utility: parse N hex FP32 values from one CSV line
    // ------------------------------------------
    task automatic parse_hex_row(
        input  string  line,
        output word_t  vals [N]
    );
        string tok;
        int    idx;
        int    pos;
        byte   ch;
        int unsigned bits;
        int    rc;

        begin
            tok = "";
            idx = 0;
            for (pos = 0; pos <= line.len(); pos++) begin
                if (pos < line.len()) ch = line[pos];
                else                  ch = ","; // sentinel

                if (ch == "," || ch == "\n" || ch == "\r") begin
                    if (tok.len() > 0) begin
                        if (idx < N) begin
                            rc = $sscanf(tok, "%h", bits);
                            if (rc == 1) begin
                                vals[idx] = word_t'(bits[31:0]);
                            end else begin
                                vals[idx] = '0;
                            end
                            idx++;
                        end
                        tok = "";
                    end
                end else begin
                    tok = {tok, ch};
                end
            end
        end
    endtask

    // ------------------------------------------
    // Main test: load conv1 tile and run DUT
    // ------------------------------------------
    initial begin : tb_main
        int addr;
        int r, c, i;
        int fd_top, fd_w;
        string line;
        word_t row_vals [N];
        logic [31:0] addr_x, addr_w;
        int cyc;

        // Initial defaults
        n_rst      = 1'b0;
        x_addr     = 32'h0000_0000;
        w_addr     = 32'h0000_1000;
        sc_x_data  = '{default:'0};
        sc_w_data  = '{default:'0};
        start_mul  = 1'b0;

        // Clear scratchpad region
        for (addr = 0; addr < 4096; addr++) begin
            sc[logic'(addr)] = '0;
        end

        // --------------------------------------
        // Load FIRST N rows x N cols from conv1 toplitz.csv
        // --------------------------------------
        $display("[TB] Opening conv1 toplitz CSV: alexnet_toplitz/layers/001_conv1/toplitz.csv");
        fd_top = $fopen("alexnet_toplitz/layers/001_conv1/toplitz.csv", "r");
        if (fd_top == 0) begin
            $display("[TB] ERROR: failed to open toplitz.csv");
            $finish;
        end

        for (r = 0; r < N; r++) begin
            if ($feof(fd_top)) begin
                $display("[TB] WARNING: toplitz.csv has fewer than %0d rows", N);
                break;
            end
            line = "";
            void'($fgets(line, fd_top));
            parse_hex_row(line, row_vals);
            for (c = 0; c < N; c++) begin
                addr_x = x_addr + r*N + c;
                sc[addr_x] = row_vals[c];
            end
        end
        $fclose(fd_top);

        // --------------------------------------
        // Load FIRST N rows x N cols from conv1 weights.csv
        // --------------------------------------
        $display("[TB] Opening conv1 weights CSV: alexnet_toplitz/layers/001_conv1/weights.csv");
        fd_w = $fopen("alexnet_toplitz/layers/001_conv1/weights.csv", "r");
        if (fd_w == 0) begin
            $display("[TB] ERROR: failed to open weights.csv");
            $finish;
        end

        for (r = 0; r < N; r++) begin
            if ($feof(fd_w)) begin
                $display("[TB] WARNING: weights.csv has fewer than %0d rows", N);
                break;
            end
            line = "";
            void'($fgets(line, fd_w));
            parse_hex_row(line, row_vals);
            for (c = 0; c < N; c++) begin
                addr_w = w_addr + r*N + c;
                sc[addr_w] = row_vals[c];
            end
        end
        $fclose(fd_w);
         // --------------------------------------
        // Load FIRST N rows x N cols from conv1 weights.csv DEBUG BLOCK
        // --------------------------------------
                // Debug: print the tile we just loaded into scratchpad
        $display("[TB] Debug: first %0d x %0d X tile from scratchpad:", N, N);
        for (r = 0; r < N; r++) begin
            for (c = 0; c < N; c++) begin
                addr_x = x_addr + r*N + c;
                $write("%0f ", $bitstoshortreal(sc[addr_x]));
            end
            $display();
        end

        $display("[TB] Debug: first %0d x %0d W tile from scratchpad:", N, N);
        for (r = 0; r < N; r++) begin
            for (c = 0; c < N; c++) begin
                addr_w = w_addr + r*N + c;
                $write("%0f ", $bitstoshortreal(sc[addr_w]));
            end
            $display();
        end

        // --------------------------------------
        // Release reset
        // --------------------------------------
        #50;
        n_rst = 1'b1;
        #50;

        // --------------------------------------
        // Start multiply and FEED scratchpad
        // --------------------------------------
        $display("[TB] Starting systolic array multiplication (conv1 4x4 tile)...");
        @(posedge clk);
        start_mul = 1'b1;
        @(posedge clk);
        start_mul = 1'b0;

        // First cycle of feeding
        for (i = 0; i < N; i++) begin
            if (sc_valid_queue[i]) begin
                sc_x_data[i] = sc[sc_x_queue[i]];
                sc_w_data[i] = sc[sc_w_queue[i]];
            end else begin
                sc_x_data[i] = '0;
                sc_w_data[i] = '0;
            end
        end

        // Continue feeding while stall_mul is asserted
        @(negedge clk);
        cyc = 0;
        while (stall_mul) begin
            for (i = 0; i < N; i++) begin
                if (sc_valid_queue[i]) begin
                    sc_x_data[i] = sc[sc_x_queue[i]];
                    sc_w_data[i] = sc[sc_w_queue[i]];
                end else begin
                    sc_x_data[i] = '0;
                    sc_w_data[i] = '0;
                end
            end
            cyc++;
            if (cyc > 100000) begin
                $display("[TB] ERROR: stall_mul stuck high, aborting.");
                $finish;
            end
            @(posedge clk);
            @(negedge clk);
        end

        // Stop feeding and print results
        start_mul = 1'b0;

        $display("[TB] Finished conv1 tile. psum matrix:");
        for (r = 0; r < N; r++) begin
            for (c = 0; c < N; c++) begin
                $write("%08f ", $bitstoshortreal(DUT.sys_array.psum[r][c]));
            end
            $display();
        end
        // Debug: print sc_valid_queue pattern for this cycle
            $write("[TB] sc_valid_queue = ");
            for (i = 0; i < N; i++) begin
                $write("%0d", sc_valid_queue[i]);
            end
            $display();

        $display("[TB] tb_conv1 completed.");
        $finish;
    end

endmodule
