`timescale 1ns/1ps

`include "systolic_array_pkg.svh"
`include "alexnet_conv1_meta.svh"

import alexnet_conv1_meta::*;

module tb_conv1;

    // ========================================================================
    // 1. GLOBAL CONFIGURATION & BUFFER
    // ========================================================================
    // Active subset: we are only checking first 128 rows, 32 channels
    localparam int M_ACTIVE    = 128;               // Rows (M)
    localparam int COUT_ACTIVE = 32;                // Output channels (C)
    // Full depth K is required for the math to match golden scalar values
    localparam int K_ACTIVE    = CONV1_IM2COL_K;    // 363

    localparam int N = SA_N; // Systolic Array Dimension (64)

    // Global accumulation buffer for RTL outputs (M x COUT subset)
    // We strictly use this for output collection and CSV dumping.
    shortreal Y_accum [0:M_ACTIVE-1][0:COUT_ACTIVE-1];

    // ========================================================================
    // 2. INPUT DATA BUFFERS
    // ========================================================================
    word_t T [M_ACTIVE][K_ACTIVE];      // im2col input
    word_t W [K_ACTIVE][COUT_ACTIVE];   // weights

    // Scratchpad (legacy compatibility)
    word_t sc [logic[31:0]];

    // ========================================================================
    // 3. DUT SIGNALS
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
    // 4. CLOCK GENERATION
    // ========================================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // 5. DUT INSTANTIATION
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
    // 6. HELPER: PARSE HEX CSV ROW
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
    // 7. TASK: LOAD MATRICES
    // ========================================================================
    task automatic load_conv1_matrices();
        int fd_top, fd_w;
        string line;
        word_t row_vals[];

        // ---- Load T ----
        $display("[TB] Loading T (toplitz) matrix from %s", CONV1_TOPLITZ_CSV);
        fd_top = $fopen(CONV1_TOPLITZ_CSV, "r");
        if (fd_top == 0) $fatal(1, "[TB] ERROR: could not open %s", CONV1_TOPLITZ_CSV);

        for (int m_idx = 0; m_idx < M_ACTIVE; m_idx++) begin
            if ($feof(fd_top)) $fatal(1, "[TB] ERROR: toplitz.csv ended early at row %0d", m_idx);
            line = "";
            void'($fgets(line, fd_top));
            parse_hex_row(line, row_vals, K_ACTIVE);
            for (int k_idx = 0; k_idx < K_ACTIVE; k_idx++) begin
                T[m_idx][k_idx] = row_vals[k_idx];
            end
        end
        $fclose(fd_top);

        // ---- Load W ----
        $display("[TB] Loading W (weights) matrix from %s", CONV1_WEIGHTS_CSV);
        fd_w = $fopen(CONV1_WEIGHTS_CSV, "r");
        if (fd_w == 0) $fatal(1, "[TB] ERROR: could not open %s", CONV1_WEIGHTS_CSV);

        for (int k_idx = 0; k_idx < K_ACTIVE; k_idx++) begin
            if ($feof(fd_w)) $fatal(1, "[TB] ERROR: weights.csv ended early at row %0d", k_idx);
            line = "";
            void'($fgets(line, fd_w));
            parse_hex_row(line, row_vals, COUT_ACTIVE);
            for (int c_idx = 0; c_idx < COUT_ACTIVE; c_idx++) begin
                W[k_idx][c_idx] = row_vals[c_idx];
            end
        end
        $fclose(fd_w);
        $display("[TB] Finished loading. Active: M=%0d, K=%0d, COUT=%0d", M_ACTIVE, K_ACTIVE, COUT_ACTIVE);
    endtask

    // ========================================================================
    // 8. TASK: RUN SINGLE TILE
    // ========================================================================
    task automatic run_tile(
        input  int m0,   
        input  int c0
    );
        int cyc;
        int k_ptr_x [N]; 
        int k_ptr_w [N];
        
        // Initialize pointers (Blocking assignment for automatic vars)
        for(int i=0; i<N; i++) begin
            k_ptr_x[i] = 0;
            k_ptr_w[i] = 0;
        end

        // 1. Setup Addresses
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
                    if (cur_m < M_ACTIVE && cur_k < K_ACTIVE) begin
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
                    if (cur_c < COUT_ACTIVE && cur_k < K_ACTIVE) begin
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

        // 4. DRAIN CYCLES
        repeat (2 * N) @(posedge clk);

        // 5. READ OUTPUT & WRITE TO Y_accum (Canonical Writeback)
        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                
                // Calculate GLOBAL indices using Tile Offsets
                int m_idx = m0 + r;
                int c_idx = c0 + c;

                // Bounds check
                if (m_idx < M_ACTIVE && c_idx < COUT_ACTIVE) begin
                    // Read psum from systolic array for this PE (r,c)
                    shortreal y_val;
                    y_val = $bitstoshortreal(DUT.sys_array.psum[r][c]);
                    
                    // Store to Global Buffer
                    Y_accum[m_idx][c_idx] = y_val;

                    // TEMP DEBUG: Catch specific indices
                    if ((m_idx == 0 && c_idx == 0) || (m_idx == 112 && c_idx == 5)) begin
                         real y_val_r = y_val;
                         $display("[TB DEBUG] writeback Y_accum[%0d][%0d] = %f", m_idx, c_idx, y_val_r);
                    end
                end
            end
        end
    endtask

    // ========================================================================
    // 9. MAIN TEST PROCESS
    // ========================================================================
    initial begin : tb_main
        integer fd_out;
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

        // Clear accumulation buffer
        for (int m = 0; m < M_ACTIVE; m++) begin
            for (int c = 0; c < COUT_ACTIVE; c++) begin
                Y_accum[m][c] = 0.0;
            end
        end

        // Reset
        repeat(10) @(posedge clk);
        n_rst = 1'b1;
        repeat(10) @(posedge clk);

        $display("----------------------------------------------------------");
        $display("[TB] AlexNet Conv1 Systolic Array Test (Active Subset)");
        $display("[TB] Mode: M=%0d, K=%0d (Full), COUT=%0d", M_ACTIVE, K_ACTIVE, COUT_ACTIVE);
        $display("----------------------------------------------------------");

        // 1. Load Data
        load_conv1_matrices();

        // ----------------------------------------------------------
        // [CHECK 1] SV-side software check: Y[0][0] = sum_k T[0,k] * W[k,0]
        // ----------------------------------------------------------
        sv_sw_y00 = 0.0;
        for (int k = 0; k < K_ACTIVE; k++) begin
            t_sr = $bitstoshortreal(T[0][k]);
            w_sr = $bitstoshortreal(W[k][0]);
            sv_sw_y00 += t_sr * w_sr;
        end
        // Use real temp for display
        begin
            real sv_sw_y00_r;
            sv_sw_y00_r = sv_sw_y00;
            $display("[TB] SV-SW Y[0][0] = %f", sv_sw_y00_r);
        end

        // ----------------------------------------------------------
        // [CHECK 2] Debug first few entries of T[0,:] and W[:,0]
        // ----------------------------------------------------------
        $display("[TB] DEBUG T[0][0..7]:");
        for (int k = 0; k < 8; k++) begin
            if (k < K_ACTIVE) begin
                dbg_t = $bitstoshortreal(T[0][k]);
                // Use real temp for display
                begin
                    real dbg_t_r;
                    dbg_t_r = dbg_t;
                    $display("  T[0][%0d] = %f (0x%08h)", k, dbg_t_r, T[0][k]);
                end
            end
        end
        $display("[TB] DEBUG W[0..7][0]:");
        for (int k = 0; k < 8; k++) begin
            if (k < K_ACTIVE) begin
                dbg_w = $bitstoshortreal(W[k][0]);
                // Use real temp for display
                begin
                    real dbg_w_r;
                    dbg_w_r = dbg_w;
                    $display("  W[%0d][0] = %f (0x%08h)", k, dbg_w_r, W[k][0]);
                end
            end
        end

        // 2. Perform Tiled Multiplication
        $display("[TB] Starting tiled multiplication...");
        
        for (int m0 = 0; m0 < M_ACTIVE; m0 += N) begin
            for (int c0 = 0; c0 < COUT_ACTIVE; c0 += N) begin
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
        rtl_y00 = Y_accum[0][0];
        begin
             real rtl_y00_r;
             rtl_y00_r = rtl_y00;
             $display("[TB] RTL Y[0][0] = %f (0x%016h)",
                      rtl_y00_r, $realtobits(rtl_y00_r));
        end

        // 3. Dump Y_accum to CSV (Linear M x COUT)
        fd_out = $fopen(CONV1_RTL_OUT_CSV, "w");
        if (fd_out == 0) $fatal(1, "[TB] ERROR: could not open %s", CONV1_RTL_OUT_CSV);

        $display("[TB] Computation finished. Writing output to %s...", CONV1_RTL_OUT_CSV);

        // Linear dump: One value per line, fp32 hex
        for (int m = 0; m < M_ACTIVE; m++) begin
            for (int c = 0; c < COUT_ACTIVE; c++) begin
                word_t bits;
                bits = $shortrealtobits(Y_accum[m][c]);
                $fdisplay(fd_out, "%08h", bits);
            end
        end

        $fclose(fd_out);
        $display("[TB] Done. RTL output saved.");
        $finish;
    end

endmodule