`timescale 1ns/1ps

`include "systolic_array_pkg.svh"
`include "toy_conv1_meta.svh"
import toy_conv1_meta::*;

module tb_toy_conv1;

  // ------------------------------------------------------------------
  // Basic configuration
  // ------------------------------------------------------------------
  localparam int N          = 4;         // systolic array dimension
  localparam int DATA_WIDTH = 32;

  // CSV paths (relative to BG_PROJECT where you run vsim)
  localparam string TOPLITZ_CSV = "toy_toplitz/layers/001_conv1/toplitz.csv";
  localparam string WEIGHTS_CSV = "toy_toplitz/layers/001_conv1/weights.csv";

  // ------------------------------------------------------------------
  // Clock / reset
  // ------------------------------------------------------------------
  logic clk;
  logic n_rst;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ------------------------------------------------------------------
  // DUT interface signals (systolic_array_top)
  // ------------------------------------------------------------------
  logic [31:0] x_addr, w_addr;

  logic [N-1:0][31:0] sc_x_queue;
  logic [N-1:0][31:0] sc_w_queue;
  logic [N-1:0]       sc_valid_queue;

  logic [N-1:0]       sc_valid_write;
  logic [N-1:0][31:0] sc_write_queue;
  logic [N-1:0][31:0] sc_write_data;

  word_t [N-1:0] sc_x_data;
  word_t [N-1:0] sc_w_data;

  logic start_mul;
  logic stall_mul;

  // Controller side (unused in this Step-1 test)
  logic        controller_sc_read_en;
  logic        controller_sc_write_en;
  logic [31:0] controller_sc_addr;
  logic [31:0] controller_sc_out;
  logic [31:0] controller_sc_in;

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
  // Local storage for one 4x4 tile and software golden result
  // ------------------------------------------------------------------
  word_t T_tile [0:N-1][0:N-1];  // 4x4 from toplitz.csv
  word_t W_tile [0:N-1][0:N-1];  // 4x4 from weights.csv
  word_t G_sw   [0:N-1][0:N-1];  // software 4x4 golden

  // ------------------------------------------------------------------
  // Task: load first 4x4 block from the toy CSVs
  // ------------------------------------------------------------------
  task automatic load_tiles_from_csv;
    int fd_t, fd_w;
    word_t t0,t1,t2,t3,t4,t5,t6,t7,t8;
    word_t w0,w1,w2,w3;
    int    r;

    // ----- T_tile: first 4 rows, first 4 cols of toplitz.csv
    fd_t = $fopen(TOPLITZ_CSV, "r");
    if (fd_t == 0) begin
      $fatal(1, "[TB] Could not open %s", TOPLITZ_CSV);
    end

    for (r = 0; r < N; r++) begin
      // Each row has 9 comma-separated hex values.
      if ($fscanf(fd_t, "%h,%h,%h,%h,%h,%h,%h,%h,%h\n",
                  t0,t1,t2,t3,t4,t5,t6,t7,t8) != 9) begin
        $fatal(1, "[TB] Failed to read row %0d from %s", r, TOPLITZ_CSV);
      end
      T_tile[r][0] = t0;
      T_tile[r][1] = t1;
      T_tile[r][2] = t2;
      T_tile[r][3] = t3;
    end
    $fclose(fd_t);

    // ----- W_tile: first 4 rows of weights.csv (each row is 4-wide)
    fd_w = $fopen(WEIGHTS_CSV, "r");
    if (fd_w == 0) begin
      $fatal(1, "[TB] Could not open %s", WEIGHTS_CSV);
    end

    for (r = 0; r < N; r++) begin
      if ($fscanf(fd_w, "%h,%h,%h,%h\n", w0,w1,w2,w3) != 4) begin
        $fatal(1, "[TB] Failed to read row %0d from %s", r, WEIGHTS_CSV);
      end
      W_tile[r][0] = w0;
      W_tile[r][1] = w1;
      W_tile[r][2] = w2;
      W_tile[r][3] = w3;
    end
    $fclose(fd_w);
  endtask

  // ------------------------------------------------------------------
  // Task: compute software golden for the 4x4 GEMM tile
  //         G_sw = T_tile (4x4) * W_tile (4x4)
  // ------------------------------------------------------------------
  task automatic compute_sw_golden;
    shortreal T_sr [0:N-1][0:N-1];
    shortreal W_sr [0:N-1][0:N-1];
    shortreal acc;

    // Convert bits -> shortreal
    for (int r = 0; r < N; r++) begin
      for (int c = 0; c < N; c++) begin
        T_sr[r][c] = $bitstoshortreal(T_tile[r][c]);
        W_sr[r][c] = $bitstoshortreal(W_tile[r][c]);
      end
    end

    // Standard GEMM
    for (int i = 0; i < N; i++) begin
      for (int j = 0; j < N; j++) begin
        acc = 0.0;
        for (int k = 0; k < N; k++) begin
          acc += T_sr[i][k] * W_sr[k][j];
        end
        G_sw[i][j] = $shortrealtobits(acc);
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Main test sequence: reset, load, run, compare
  // ------------------------------------------------------------------
  initial begin : main_test
    int errors;

    // Defaults
    n_rst                  = 0;
    start_mul              = 0;
    controller_sc_read_en  = 0;
    controller_sc_write_en = 0;
    controller_sc_addr     = '0;
    controller_sc_in       = '0;

    // Base scratchpad addresses (non-overlapping regions)
    x_addr = 32'h0000_0000;
    w_addr = 32'h0000_0100;

    // 1) Reset
    repeat (5) @(posedge clk);
    n_rst = 1;

    // 2) Load tiles and compute software golden
    load_tiles_from_csv();
    compute_sw_golden();

    // 3) Program scratchpad contents for this tile
    //    Layout matches the style used in tb_new_working:
    //      sc[x_addr + r*N + c] = T_tile[r][c]
    //      sc[w_addr + r*N + c] = W_tile[r][c]
    for (int r = 0; r < N; r++) begin
      for (int c = 0; c < N; c++) begin
        sc[x_addr + r*N + c] = T_tile[r][c];
        sc[w_addr + r*N + c] = W_tile[r][c];
      end
    end

    // 4) Start systolic array
    @(posedge clk);
    start_mul = 1'b1;
    @(posedge clk);
    start_mul = 1'b0;

    // 5) Let it run. For N=4, 100 cycles is plenty.
    repeat (100) @(posedge clk);

    // 6) Compare DUT psums vs software golden
    errors = 0;
    $display("--------------------------------------------------");
    $display(" PE Engine Check (4x4 tile from toy_toplitz) ");
    $display("--------------------------------------------------");

    for (int r = 0; r < N; r++) begin
      for (int c = 0; c < N; c++) begin
        word_t rtl;
        word_t gold;

        rtl  = dut.sys_array.psum[r][c];
        gold = G_sw[r][c];

        if (rtl !== gold) begin
          $display("MISMATCH (%0d,%0d): RTL=%08h  GOLD=%08h",
                   r, c, rtl, gold);
          errors++;
        end
        else begin
          $display("MATCH    (%0d,%0d): %08h", r, c, rtl);
        end
      end
    end

    if (errors == 0)
      $display("[TB] PE compute engine PASSED for toy 4x4 tile.");
    else
      $display("[TB] PE compute engine FAILED: %0d mismatches.", errors);

    $finish;
  end

endmodule
