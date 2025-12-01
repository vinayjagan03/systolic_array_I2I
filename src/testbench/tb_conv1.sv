`timescale 1ns/1ps

`include "systolic_array_pkg.svh"
`include "alexnet_conv1_meta.svh"

import alexnet_conv1_meta::*;

module tb_conv1;

    // ========================================================================
    // 1. DEBUG CONFIGURATION
    // ========================================================================
    // M/COUT subset for speed, but FULL K for correctness.
    localparam int M_DBG    = 128;               
    localparam int K_DBG    = CONV1_IM2COL_K;    // 363 (FULL DEPTH)
    localparam int COUT_DBG = 32;                

    localparam int M    = (M_DBG    < CONV1_IM2COL_M)     ? M_DBG    : CONV1_IM2COL_M;
    localparam int K    = (K_DBG    < CONV1_IM2COL_K)     ? K_DBG    : CONV1_IM2COL_K;
    localparam int COUT = (COUT_DBG < CONV1_WEIGHTS_COUT) ? COUT_DBG : CONV1_WEIGHTS_COUT;
    
    localparam int N    = SA_N; // 64

    // ========================================================================
    // 2. Global Buffers
    // ========================================================================
    word_t T [M][K];          // im2col input
    word_t W [K][COUT];       // weights
    shortreal Y [M][COUT];    // output

    // Scratchpad not used for streaming, but kept for compatibility
    word_t sc [logic[31:0]];

    // ========================================================================
    // 3. DUT Signals
    // ========================================================================
    logic clk, n_rst;
    
    logic [31:0] x_addr;
    logic [31:0] w_addr;

    logic [N-1:0][31:0] sc_x_queue;
    logic [N-1:0][31:0] sc_w_queue;
    logic [N-1:0]       sc_valid_queue;
    word_t [N-1:0]      sc_x_data;
    word_t [N-1:0]      sc_w_data;
    logic               start_mul;
    logic               stall_mul;

    // ========================================================================
    // 4. Clock Generation
    // ========================================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // 5. DUT Instantiation
    // ========================================================================
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

    // ========================================================================
    // 6. Helper: Parse Hex CSV Row
    // ========================================================================
    function void parse_hex_row(
        input  string line,
        output word_t values[],
        input  int    max_cols
    );
        string tok;
        int    idx;
        int    pos;
        int    len;
        int    rc;

        values = new[max_cols];
        idx    = 0;
        len    = line.len();

        while (len > 0 && idx < max_cols) begin
            pos = -1;
            for (int i = 0; i < len; i++) begin
                if (line[i] == ",") begin
                    pos = i;
                    break;
                end
            end
            if (pos == -1) begin
                tok = line;
                line = "";
                len  = 0;
            end else begin
                if (pos > 0) tok = line.substr(0, pos-1);
                else         tok = "";
                if (pos+1 < len) line = line.substr(pos+1, len-1);
                else             line = "";
                len = line.len();
            end
            if (tok.len() != 0) begin
                int unsigned bits;
                rc = $sscanf(tok, "%h", bits);
                if (rc == 1) values[idx] = word_t'(bits);
                else         values[idx] = '0;
                idx++;
            end
        end
        while (idx < max_cols) begin
            values[idx] = '0;
            idx++;
        end
    endfunction

    // ========================================================================
    // 7. Task: Load Matrices
    // ========================================================================
    task automatic load_conv1_matrices();
        int fd_top, fd_w;
        string line;
        word_t row_vals[];

        // ---- Load T ----
        $display("[TB] Loading T (toplitz) matrix from %s", CONV1_TOPLITZ_CSV);
        fd_top = $fopen(CONV1_TOPLITZ_CSV, "r");
        if (fd_top == 0) $fatal(1, "[TB] ERROR: could not open %s", CONV1_TOPLITZ_CSV);

        for (int m_idx = 0; m_idx < M; m_idx++) begin
            if ($feof(fd_top)) $fatal(1, "[TB] ERROR: toplitz.csv ended early at row %0d", m_idx);
            line = "";
            void'($fgets(line, fd_top));
            parse_hex_row(line, row_vals, K);
            for (int k_idx = 0; k_idx < K; k_idx++) begin
                T[m_idx][k_idx] = row_vals[k_idx];
            end
        end
        $fclose(fd_top);

        // ---- Load W ----
        $display("[TB] Loading W (weights) matrix from %s", CONV1_WEIGHTS_CSV);
        fd_w = $fopen(CONV1_WEIGHTS_CSV, "r");
        if (fd_w == 0) $fatal(1, "[TB] ERROR: could not open %s", CONV1_WEIGHTS_CSV);

        for (int k_idx = 0; k_idx < K; k_idx++) begin
            if ($feof(fd_w)) $fatal(1, "[TB] ERROR: weights.csv ended early at row %0d", k_idx);
            line = "";
            void'($fgets(line, fd_w));
            parse_hex_row(line, row_vals, COUT);
            for (int c_idx = 0; c_idx < COUT; c_idx++) begin
                W[k_idx][c_idx] = row_vals[c_idx];
            end
        end
        $fclose(fd_w);
        $display("[TB] Finished loading. Active: M=%0d, K=%0d, COUT=%0d", M, K, COUT);
    endtask

    // ========================================================================
    // 8. Task: Run Single Tile
    // ========================================================================
    task automatic run_tile(
        input  int m0,   
        input  int c0
    );
        int cyc;
        
        // Local counters for this automatic task
        int k_ptr_x [N]; 
        int k_ptr_w [N];
        
        // Initialize pointers using Blocking Assignment
        for(int i=0; i<N; i++) begin
            k_ptr_x[i] = 0;
            k_ptr_w[i] = 0;
        end

        // 1. Setup Addresses (Dummy)
        x_addr <= 32'h0;
        w_addr <= 32'h0;

        // 2. Pulse Start
        @(negedge clk);
        start_mul <= 1'b1;
        @(negedge clk);
        start_mul <= 1'b0;

        // Wait a cycle for stall_mul to assert
        @(posedge clk); 

        // 3. Streaming Feed Loop
        cyc = 0;
        while (stall_mul) begin
            
            for (int i = 0; i < N; i++) begin
                // Handle X Feed
                if (sc_valid_queue[i]) begin
                    int cur_m = m0 + i;
                    int cur_k = k_ptr_x[i];

                    // T is [M][K] => T[row][col]
                    if (cur_m < M && cur_k < K) begin
                        sc_x_data[i] <= T[cur_m][cur_k];
                        k_ptr_x[i]    = cur_k + 1; // Blocking
                    end else begin
                        sc_x_data[i] <= '0;
                    end
                end else begin
                    sc_x_data[i] <= '0;
                end

                // Handle W Feed
                if (sc_valid_queue[i]) begin
                    int cur_c = c0 + i;
                    int cur_k = k_ptr_w[i];

                    // W is [K][COUT] => W[row][col]
                    if (cur_c < COUT && cur_k < K) begin
                        sc_w_data[i] <= W[cur_k][cur_c];
                        k_ptr_w[i]    = cur_k + 1; // Blocking
                    end else begin
                        sc_w_data[i] <= '0;
                    end
                end else begin
                    sc_w_data[i] <= '0;
                end
            end

            cyc++; 
            if ((cyc % 5000) == 0) begin
                $display("[TB]   ...streaming K-slices, cyc=%0d. (m0=%0d, c0=%0d)", cyc, m0, c0);
            end
            if (cyc > 200000) begin
                $fatal(1, "[TB] ERROR: stall_mul stuck > 200k cycles. Deadlock?");
            end

            @(posedge clk);
            @(negedge clk);
        end

        // 4. Drain Cycles
        repeat (2 * N) @(posedge clk);

        // 5. Read Output & Accumulate
        for (int r = 0; r < N; r++) begin
            int m_idx = m0 + r;
            if (m_idx >= M) continue;

            for (int c = 0; c < N; c++) begin
                int c_idx = c0 + c;
                if (c_idx >= COUT) continue;
                
                Y[m_idx][c_idx] += $bitstoshortreal(DUT.sys_array.psum[r][c]);
            end
        end
    endtask

    // ========================================================================
    // 9. Main Test Process
    // ========================================================================
    initial begin : tb_main
        int fd_out;
        int tile_id; 
        
        // Variables for checks
        shortreal sv_sw_y00;
        shortreal t_sr, w_sr;
        shortreal dbg_t, dbg_w;
        shortreal rtl_y00;
        
        n_rst      = 1'b0;
        start_mul  = 1'b0;
        x_addr     = '0;
        w_addr     = '0;
        sc_x_data  = '{default:'0};
        sc_w_data  = '{default:'0};
        tile_id    = 0;

        // Clear Y buffer
        for (int m = 0; m < M; m++) begin
            for (int c = 0; c < COUT; c++) begin
                Y[m][c] = 0.0;
            end
        end

        // Reset
        repeat(10) @(posedge clk);
        n_rst = 1'b1;
        repeat(10) @(posedge clk);

        $display("----------------------------------------------------------");
        $display("[TB] AlexNet Conv1 Systolic Array Test");
        $display("[TB] Mode: M=%0d, K=%0d (Full), COUT=%0d", M, K, COUT);
        $display("----------------------------------------------------------");

        // 1. Load Data
        load_conv1_matrices();

        // ----------------------------------------------------------
        // [CHECK 1] SV-side software check: Y[0][0] = sum_k T[0,k] * W[k,0]
        // (operating on FP32 bit patterns using $bitstoshortreal)
        // ----------------------------------------------------------
        sv_sw_y00 = 0.0;

        for (int k = 0; k < K; k++) begin
            t_sr = $bitstoshortreal(T[0][k]);   // T bits -> float
            w_sr = $bitstoshortreal(W[k][0]);   // W bits -> float
            sv_sw_y00 += t_sr * w_sr;
        end

        $display("[TB] SV-SW Y[0][0] = %f", sv_sw_y00);

        // ----------------------------------------------------------
        // [CHECK 2] Debug first few entries of T[0,:] and W[:,0]
        // ----------------------------------------------------------
        $display("[TB] DEBUG T[0][0..7]:");
        for (int k = 0; k < 8; k++) begin
            if (k < K) begin
                dbg_t = $bitstoshortreal(T[0][k]);
                $display("  T[0][%0d] = %f (0x%08h)",
                         k, dbg_t, T[0][k]);  // hex = raw FP32 bits
            end
        end

        $display("[TB] DEBUG W[0..7][0]:");
        for (int k = 0; k < 8; k++) begin
            if (k < K) begin
                dbg_w = $bitstoshortreal(W[k][0]);
                $display("  W[%0d][0] = %f (0x%08h)",
                         k, dbg_w, W[k][0]);  // hex = raw FP32 bits
            end
        end

        // 2. Perform Tiled Multiplication
        $display("[TB] Starting tiled multiplication...");
        
        for (int m0 = 0; m0 < M; m0 += N) begin
            for (int c0 = 0; c0 < COUT; c0 += N) begin
                tile_id++;
                $display("[TB] [Tile %0d] Processing Block: m0=%0d..%0d, c0=%0d..%0d", 
                         tile_id, m0, m0+N-1, c0, c0+N-1);

                run_tile(m0, c0);
            end
            $display("[TB] Row-Block Complete: m=%0d", m0);
        end

        // ----------------------------------------------------------
        // [CHECK 3] Check RTL output for Y[0][0]
        // ----------------------------------------------------------
        rtl_y00 = Y[0][0];
        // Note: rtl_y00 is already a shortreal/float, so we can just print it.
        // We use $shortrealtobits here to see the hex representation of the result.
        // If your simulator complains about shortrealtobits on a shortreal variable,
        // you can cast or use the temp variable trick again.
        // But usually $shortrealtobits(shortreal_var) is valid.
        begin
             real rtl_y00_r;
             rtl_y00_r = rtl_y00;
             $display("[TB] RTL Y[0][0] = %f (0x%016h)",
                      rtl_y00_r, $realtobits(rtl_y00_r));
        end

        // 3. Dump Output to CSV
        $display("[TB] Computation finished. Writing output to %s...", CONV1_RTL_OUT_CSV);
        
        fd_out = $fopen(CONV1_RTL_OUT_CSV, "w");
        if (fd_out == 0) $fatal(1, "[TB] ERROR: could not open %s", CONV1_RTL_OUT_CSV);

        if (M < CONV1_IM2COL_M || COUT < CONV1_WEIGHTS_COUT) begin
            // Debug linear dump
            for (int m_idx = 0; m_idx < M; m_idx++) begin
                for (int c = 0; c < COUT; c++) begin
                    word_t bits;
                    bits = $shortrealtobits(Y[m_idx][c]);
                    $fwrite(fd_out, "%08h", bits);
                    if (c != COUT - 1) $fwrite(fd_out, ",");
                end
                $fwrite(fd_out, "\n");
            end
        end else begin
            // Full structured dump
            for (int h = 0; h < CONV1_OUT_H; h++) begin
                for (int w = 0; w < CONV1_OUT_W; w++) begin
                    int m_idx;
                    m_idx = h * CONV1_OUT_W + w; 
                    for (int c = 0; c < CONV1_OUT_C; c++) begin
                        word_t bits;
                        bits = $shortrealtobits(Y[m_idx][c]);
                        $fwrite(fd_out, "%08h", bits);
                        if (c != CONV1_OUT_C - 1) $fwrite(fd_out, ",");
                    end
                    $fwrite(fd_out, "\n");
                end
            end
        end

        $fclose(fd_out);
        $display("[TB] Done. RTL output saved.");
        $finish;
    end

endmodule