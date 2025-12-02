`timescale 1ns/1ps

`include "systolic_array_pkg.svh"
`include "toy_conv1_meta.svh"
import toy_conv1_meta::*;

module tb_toy_conv1;

  // ------------------------------------------------------------------
  // Basic configuration for toy_conv1
  // ------------------------------------------------------------------
  localparam int N       = 4;   // systolic array dimension
  localparam int M       = 25;  // rows of T and G (flattened 5x5)
  localparam int K       = 9;   // inner dimension
  localparam int C_OUT   = 4;   // output channels

  // CSV paths (relative to BG_PROJECT where you run vsim)
  localparam string TOPLITZ_CSV    = "toy_toplitz/layers/001_conv1/toplitz.csv";
  localparam string WEIGHTS_CSV    = "toy_toplitz/layers/001_conv1/weights.csv";
  localparam string GOLDEN_OUT_CSV = "toy_toplitz/layers/001_conv1/golden_output.csv";
  localparam string RTL_OUT_CSV    = "toy_toplitz/layers/001_conv1/rtl_output.csv";

  // Number of tiles
  localparam int NUM_M_TILES = (M + N - 1) / N; // ceil(M / N)
  localparam int NUM_K_TILES = (K + N - 1) / N; // ceil(K / N)

  // ------------------------------------------------------------------
  // Clock / reset
  // ------------------------------------------------------------------
  logic clk;
  logic n_rst;

  // ------------------------------------------------------------------
  // DEBUG MONITOR VARIABLE
  // ------------------------------------------------------------------
  int dbg_cycle;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ------------------------------------------------------------------
  // DUT interface signals (systolic_array_top)
  // ------------------------------------------------------------------
  logic [31:0]        x_addr, w_addr;
  logic [N-1:0][31:0] sc_x_queue;
  logic [N-1:0][31:0] sc_w_queue;
  logic [N-1:0]       sc_valid_queue;
  logic [N-1:0]       sc_valid_write;
  logic [N-1:0][31:0] sc_write_queue;
  logic [N-1:0][31:0] sc_write_data;

  word_t [N-1:0]      sc_x_data;
  word_t [N-1:0]      sc_w_data;

  logic               start_mul;
  logic               stall_mul;

  // Controller side (unused in this toy tiler test)
  logic               controller_sc_read_en;
  logic               controller_sc_write_en;
  logic [31:0]        controller_sc_addr;
  logic [31:0]        controller_sc_out;
  logic [31:0]        controller_sc_in;

  // ------------------------------------------------------------------
  // Scratchpad model – associative array: address -> FP32 word
  // ------------------------------------------------------------------
  word_t sc [logic[31:0]];

  // ------------------------------------------------------------------
  // DUT instantiation
  // ------------------------------------------------------------------
  systolic_array_top #(
    .N (N)
  ) dut (
    .clk                   (clk),
    .n_rst                 (n_rst),

    .x_addr                (x_addr),
    .w_addr                (w_addr),

    .sc_x_queue            (sc_x_queue),
    .sc_w_queue            (sc_w_queue),
    .sc_valid_queue        (sc_valid_queue),

    .sc_valid_write        (sc_valid_write),
    .sc_write_queue        (sc_write_queue),
    .sc_write_data         (sc_write_data),

    .sc_x_data             (sc_x_data),
    .sc_w_data             (sc_w_data),

    .start_mul             (start_mul),
    .stall_mul             (stall_mul),

    .controller_sc_read_en (controller_sc_read_en),
    .controller_sc_write_en(controller_sc_write_en),
    .controller_sc_addr    (controller_sc_addr),
    .controller_sc_out     (controller_sc_out),
    .controller_sc_in      (controller_sc_in)
  );

  // ------------------------------------------------------------------
  // Feed sc_x_data / sc_w_data from scratchpad whenever DUT requests
  // ------------------------------------------------------------------
  always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
      sc_x_data <= '{default:'0};
      sc_w_data <= '{default:'0};
    end else begin
      for (int i = 0; i < N; i++) begin
        if (sc_valid_queue[i]) begin
          sc_x_data[i] <= sc[sc_x_queue[i]];
          sc_w_data[i] <= sc[sc_w_queue[i]];
        end else begin
          sc_x_data[i] <= '0;
          sc_w_data[i] <= '0;
        end
      end
    end
  end

  // ------------------------------------------------------------------
  // DEBUG: print internal behavior for tile (0,1)
  // ------------------------------------------------------------------
  always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
      dbg_cycle <= 0;
    end else begin
      dbg_cycle <= dbg_cycle + 1;

      // Limit printout so log doesn't explode
      if (dbg_cycle < 60) begin
        $display(
          "DBG cyc=%0d | st=%0d ctr=%0d buf_ctr0=%0d start=%b | v_q0=%b xq0=%h wq0=%h | xd0=%h wd0=%h | psum00=%h",
          dbg_cycle,
          dut.state,
          dut.counter,
          dut.buffer_counters[0],
          dut.buffer_start,
          sc_valid_queue[0],
          sc_x_queue[0],
          sc_w_queue[0],
          sc_x_data[0],
          sc_w_data[0],
          dut.sys_array.psum[0][0]
        );
      end
    end
  end

  // ------------------------------------------------------------------
  // Full matrices in TB: T, W, golden G, and hardware G
  // ------------------------------------------------------------------
  word_t T_full   [0:M-1][0:K-1];     // from toplitz.csv
  word_t W_full   [0:K-1][0:C_OUT-1]; // from weights.csv
  word_t G_gold   [0:M-1][0:C_OUT-1]; // from golden_output.csv
  word_t G_hw     [0:M-1][0:C_OUT-1]; // accumulated hardware result

  // ------------------------------------------------------------------
  // Tasks for loading CSVs
  // ------------------------------------------------------------------
  task automatic load_toplitz;
    int fd;
    word_t t0,t1,t2,t3,t4,t5,t6,t7,t8;
    int m;
    fd = $fopen(TOPLITZ_CSV, "r");
    if (fd == 0) begin
      $fatal(1, "[TB] Could not open %s", TOPLITZ_CSV);
    end
    for (m = 0; m < M; m++) begin
      if ($fscanf(fd, "%h,%h,%h,%h,%h,%h,%h,%h,%h\n",
                  t0,t1,t2,t3,t4,t5,t6,t7,t8) != 9) begin
        $fatal(1, "[TB] Failed to read row %0d from %s", m, TOPLITZ_CSV);
      end
      T_full[m][0] = t0;
      T_full[m][1] = t1;
      T_full[m][2] = t2;
      T_full[m][3] = t3;
      T_full[m][4] = t4;
      T_full[m][5] = t5;
      T_full[m][6] = t6;
      T_full[m][7] = t7;
      T_full[m][8] = t8;
    end
    $fclose(fd);
  endtask

  task automatic load_weights;
    int fd;
    word_t w0,w1,w2,w3;
    int k_idx;
    fd = $fopen(WEIGHTS_CSV, "r");
    if (fd == 0) begin
      $fatal(1, "[TB] Could not open %s", WEIGHTS_CSV);
    end
    for (k_idx = 0; k_idx < K; k_idx++) begin
      if ($fscanf(fd, "%h,%h,%h,%h\n",
                  w0,w1,w2,w3) != 4) begin
        $fatal(1, "[TB] Failed to read row %0d from %s", k_idx, WEIGHTS_CSV);
      end
      W_full[k_idx][0] = w0;
      W_full[k_idx][1] = w1;
      W_full[k_idx][2] = w2;
      W_full[k_idx][3] = w3;
    end
    $fclose(fd);
  endtask

  task automatic load_golden;
    int fd;
    int m;
    word_t g0,g1,g2,g3;
    fd = $fopen(GOLDEN_OUT_CSV, "r");
    if (fd == 0) begin
      $fatal(1, "[TB] Could not open %s", GOLDEN_OUT_CSV);
    end
    for (m = 0; m < M; m++) begin
      if ($fscanf(fd, "%h,%h,%h,%h\n", g0,g1,g2,g3) != 4) begin
        $fatal(1, "[TB] Failed to read row %0d from %s", m, GOLDEN_OUT_CSV);
      end
      G_gold[m][0] = g0;
      G_gold[m][1] = g1;
      G_gold[m][2] = g2;
      G_gold[m][3] = g3;
    end
    $fclose(fd);
  endtask

  // ------------------------------------------------------------------
  // Main test sequence: full tiling over M and K, accumulate into G_hw
  // ------------------------------------------------------------------
  initial begin : full_toy_layer_test
    // Declarations MUST come before any statements in this block
    int        errors;
    shortreal  tol;

    int        m, c;
    int        m_tile, k_tile;
    int        row_start, row_count;
    int        k_start,  k_count;
    int        r, cc, kk;
    int        global_row;
    int        fd_out;

    // Tile and bit-level vars
    word_t     T_tile [0:N-1][0:N-1];
    word_t     W_tile [0:N-1][0:N-1];

    word_t     rtl_bits;
    word_t     hw_bits, gold_bits;
    shortreal  rtl_sr, old_sr, new_sr;
    shortreal  hw_sr, gold_sr, diff;

    // Intermediate variables for tile-level debug check
    shortreal  T_sr [0:N-1][0:N-1];
    shortreal  W_sr [0:N-1][0:N-1];
    shortreal  P_sw [0:N-1][0:N-1];
    shortreal  acc_tile;
    shortreal  rtl_tile, sw_tile, d_tile;

    // --------------------------------------------------------------
    // Defaults / reset
    // --------------------------------------------------------------
    n_rst                  = 0;
    start_mul              = 0;
    controller_sc_read_en  = 0;
    controller_sc_write_en = 0;
    controller_sc_addr     = '0;
    controller_sc_in       = '0;

    // Base scratchpad addresses (non-overlapping regions)
    x_addr = 32'h0000_0000;
    w_addr = 32'h0000_0100;

    tol = 1.0e-5;

    // Global reset
    repeat (5) @(posedge clk);
    n_rst = 1;

    // --------------------------------------------------------------
    // Load full matrices from CSV
    // --------------------------------------------------------------
    load_toplitz();
    load_weights();
    load_golden();

    // Initialize G_hw to 0.0
    for (m = 0; m < M; m++) begin
      for (c = 0; c < C_OUT; c++) begin
        G_hw[m][c] = $shortrealtobits(0.0);
      end
    end

    // --------------------------------------------------------------
    // Tiling loops over M and K (DEBUG: single tile)
    // --------------------------------------------------------------
    // DEBUG: run only m_tile=0, k_tile=1
    for (m_tile = 0; m_tile <= 0; m_tile++) begin
      row_start = m_tile * N;
      if (row_start + N <= M)
        row_count = N;
      else
        row_count = M - row_start;

      for (k_tile = 1; k_tile <= 1; k_tile++) begin
        k_start = k_tile * N;
        if (k_start + N <= K)
          k_count = N;
        else
          k_count = K - k_start;

        // ----------------------------------------------------------
        // Build 4x4 tiles for this (m_tile, k_tile) with padding
        // ----------------------------------------------------------
        for (r = 0; r < N; r++) begin
          for (cc = 0; cc < N; cc++) begin
            // T_tile: rows M, cols K
            if ((r < row_count) && (cc < k_count))
              T_tile[r][cc] = T_full[row_start + r][k_start + cc];
            else
              T_tile[r][cc] = $shortrealtobits(0.0);

            // W_tile: rows K, cols C_OUT
            if (r < k_count)
              W_tile[r][cc] = W_full[k_start + r][cc];  // cc is output channel
            else
              W_tile[r][cc] = $shortrealtobits(0.0);
          end
        end

        // ----------------------------------------------------------
        // Program scratchpad for this tile
        // ----------------------------------------------------------
        for (r = 0; r < N; r++) begin
          for (cc = 0; cc < N; cc++) begin
            sc[x_addr + r*N + cc] = T_tile[r][cc];
            sc[w_addr + r*N + cc] = W_tile[r][cc];
          end
        end

        // ----------------------------------------------------------
        // Reset DUT to clear psums for this tile
        // ----------------------------------------------------------
        n_rst = 0;
        @(posedge clk);
        n_rst = 1;
        @(posedge clk);

        // Start systolic array
        start_mul = 1'b1;
        @(posedge clk);
        start_mul = 1'b0;

        // Let it run; 100 cycles is plenty for N=4
        repeat (100) @(posedge clk);

        // ----------------------------------------------------------
        // Tile-level check: RTL psums vs SW GEMM for this tile
        // ----------------------------------------------------------
        // Bits -> shortreal
        for (r = 0; r < N; r++) begin
          for (cc = 0; cc < N; cc++) begin
            T_sr[r][cc] = $bitstoshortreal(T_tile[r][cc]);
            W_sr[r][cc] = $bitstoshortreal(W_tile[r][cc]);
            P_sw[r][cc] = 0.0;
          end
        end

        // GEMM: P_sw = T_tile (4x4) * W_tile (4x4)
        for (r = 0; r < N; r++) begin
          for (cc = 0; cc < N; cc++) begin
            acc_tile = 0.0;
            for (kk = 0; kk < N; kk++) begin
              acc_tile += T_sr[r][kk] * W_sr[kk][cc];
            end
            P_sw[r][cc] = acc_tile;
          end
        end

        // Compare RTL psums vs P_sw for this tile
        for (r = 0; r < row_count; r++) begin
          for (cc = 0; cc < C_OUT; cc++) begin
            rtl_bits = dut.sys_array.psum[r][cc];
            rtl_tile = $bitstoshortreal(rtl_bits);
            sw_tile  = P_sw[r][cc];
            d_tile   = (rtl_tile > sw_tile) ? (rtl_tile - sw_tile) : (sw_tile - rtl_tile);

            if (d_tile > 1.0e-5) begin
              $display("TILE MISMATCH: m_tile=%0d k_tile=%0d (r=%0d,c=%0d) RTL=%.8f SW=%.8f |diff|=%.3e",
                       m_tile, k_tile, r, cc, rtl_tile, sw_tile, d_tile);
            end
          end
        end

        // ----------------------------------------------------------
        // Accumulate this tile's psums into G_hw
        // ----------------------------------------------------------
        for (r = 0; r < N; r++) begin
          if (r < row_count) begin
            global_row = row_start + r;

            for (cc = 0; cc < C_OUT; cc++) begin
              rtl_bits = dut.sys_array.psum[r][cc];
              rtl_sr   = $bitstoshortreal(rtl_bits);

              old_sr   = $bitstoshortreal(G_hw[global_row][cc]);
              new_sr   = old_sr + rtl_sr;
              G_hw[global_row][cc] = $shortrealtobits(new_sr);
            end
          end
        end

      end // k_tile
    end // m_tile

    // --------------------------------------------------------------
    // Compare G_hw vs G_gold with tolerance
    // --------------------------------------------------------------
    // DEBUG: Disabled global check because we are only running a partial calculation
    if (0) begin
        errors = 0;
        $display("==================================================");
        $display(" FULL TOY LAYER CHECK vs golden_output.csv ");
        $display("==================================================");

        for (m = 0; m < M; m++) begin
          for (c = 0; c < C_OUT; c++) begin
            hw_bits   = G_hw[m][c];
            gold_bits = G_gold[m][c];

            hw_sr   = $bitstoshortreal(hw_bits);
            gold_sr = $bitstoshortreal(gold_bits);
            diff    = (hw_sr > gold_sr) ? (hw_sr - gold_sr) : (gold_sr - hw_sr);

            if (diff > tol) begin
              $display("MISMATCH (row=%0d, ch=%0d): HW=%08h (%.8f) GOLD=%08h (%.8f) |diff|=%.3e",
                       m, c,
                       hw_bits,  hw_sr,
                       gold_bits, gold_sr,
                       diff);
              errors++;
            end
          end
        end

        if (errors == 0)
          $display("[TB] FULL TOY LAYER MATCHES golden_output.csv ✅");
        else
          $display("[TB] FULL TOY LAYER FAILED: %0d mismatches ❌", errors);
    end
    else begin
        $display("[TB] Global check disabled for single-tile debug run.");
    end

    // --------------------------------------------------------------
    // Optional: dump HW results to CSV in same layout as golden
    // --------------------------------------------------------------
    fd_out = $fopen(RTL_OUT_CSV, "w");
    if (fd_out != 0) begin
      for (m = 0; m < M; m++) begin
        $fwrite(fd_out, "%08h,%08h,%08h,%08h\n",
                G_hw[m][0],
                G_hw[m][1],
                G_hw[m][2],
                G_hw[m][3]);
      end
      $fclose(fd_out);
      $display("[TB] Wrote RTL layer output to %s", RTL_OUT_CSV);
    end
    else begin
      $display("[TB] WARNING: Could not open %s for writing", RTL_OUT_CSV);
    end

    $finish;
  end

endmodule