`timescale 1ns/1ps
`include "systolic_array_pkg.svh"

module tb_top_pd_full_matrix;

  localparam int N  = 4;
  localparam int AW = 6;   // 64-deep SPAD

  // ------------------------------------------
  // Clock / Reset
  // ------------------------------------------
  logic clk, n_rst;
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // DUT I/O
  logic                   start_i;
  logic [AW-1:0]          base_x, base_w;
  logic                   busy, stall_sa;
  word_t                  y_bus [N-1:0];
  logic [$clog2(N)-1:0] y_index;

  // TB preload (SPAD port0; ACTIVE-LOW)
  logic                   spad_x_csb0, spad_w_csb0;
  logic [AW-1:0]          spad_x_addr0, spad_w_addr0;
  word_t                  spad_x_din0,  spad_w_din0;

  // ------------------------------------------
  // DUT
  // ------------------------------------------
  top_pd #(.N(N), .AW(AW)) DUT (
    .clk(clk), .n_rst(n_rst),
    .start_i(start_i),
    .base_addr_x(base_x),
    .base_addr_w(base_w),
    .busy_o(busy),
    .sa_stall_o(stall_sa),
    .y_out(y_bus),
    .spad_x_csb0(spad_x_csb0),
    .spad_x_addr0(spad_x_addr0),
    .spad_x_din0 (spad_x_din0),
    .spad_w_csb0(spad_w_csb0),
    .spad_w_addr0(spad_w_addr0),
    .spad_w_din0 (spad_w_din0),
    .y_index(y_index)
  );

  // ------------------------------------------
  // Helpers
  // ------------------------------------------
  function automatic word_t fp(input real r);
    fp = $shortrealtobits(shortreal'(r));
  endfunction

  function automatic [AW-1:0] addr_x(input int r, input int c, input [AW-1:0] base);
    return base + (r*N + c);
  endfunction

  // PORT0 writes
  task automatic spad_x_write(input [AW-1:0] a, input word_t d);
    spad_x_addr0 = a;  spad_x_din0 = d;
    spad_x_csb0  = 1'b0; @(posedge clk);
    spad_x_csb0  = 1'b1; @(posedge clk);
  endtask

  task automatic spad_w_write(input [AW-1:0] a, input word_t d);
    spad_w_addr0 = a;  spad_w_din0 = d;
    spad_w_csb0  = 1'b0; @(posedge clk);
    spad_w_csb0  = 1'b1; @(posedge clk);
  endtask

  task automatic pulse_start_once();
    wait (n_rst === 1'b1);
    wait (busy === 1'b0);
    @(posedge clk); start_i <= 1'b1;
    @(posedge clk); start_i <= 1'b0;
  endtask

//   // ------------------------------------------
//   // Minimal VCD
//   // ------------------------------------------
//   initial begin
//     $dumpfile("run.vcd");
//     $dumpvars(1, tb_top_pd_full_matrix);

//     $dumpvars(0,
//       tb_top_pd_full_matrix.DUT.st_q,
//       tb_top_pd_full_matrix.DUT.idx_q,
//       tb_top_pd_full_matrix.DUT.csb1_x_q,
//       tb_top_pd_full_matrix.DUT.addr1_x_q,
//       tb_top_pd_full_matrix.DUT.dout1_x,
//       tb_top_pd_full_matrix.DUT.csb1_w_q,
//       tb_top_pd_full_matrix.DUT.addr1_w_q,
//       tb_top_pd_full_matrix.DUT.dout1_w,
//       tb_top_pd_full_matrix.DUT.x_vec,
//       tb_top_pd_full_matrix.DUT.w_vec,
//       tb_top_pd_full_matrix.DUT.sa_start_q,
//       tb_top_pd_full_matrix.DUT.U_SA.start,
//       tb_top_pd_full_matrix.DUT.U_SA.x_in,
//       tb_top_pd_full_matrix.DUT.U_SA.w_in,
//       tb_top_pd_full_matrix.DUT.U_SA.y_out
//     );
//   end

  // Timeout
  initial begin
    #2_000_000;
    $display("[TB] TIMEOUT — ending sim.");
    $finish;
  end


  // ------------------------------------------
  // Matrices + selection
  // ------------------------------------------
  real    X_mat [N][N];
  integer r_sel, c_sel;

  // ------------------------------------------
  // Stimulus
  // ------------------------------------------
  initial begin
    n_rst = 0;
    start_i = 0;
    spad_x_csb0 = 1'b1; spad_w_csb0 = 1'b1;
    spad_x_addr0 = '0;  spad_w_addr0 = '0;
    spad_x_din0  = '0;  spad_w_din0  = '0;
    y_index = 0;


    // Choose row/col
    r_sel = 0;
    c_sel = 0;
    base_x = r_sel * N;
    base_w = c_sel * N;

    // Init X = 1..16
    for (int r = 0; r < N; r++)
      for (int c = 0; c < N; c++)
        X_mat[r][c] = r*N + c + 1;

    repeat (5) @(posedge clk);
    n_rst = 1;
    repeat (2) @(posedge clk);

    $display("Controller sending data to X_SC");
    // ---- Preload X row-major ----
    for (int r = 0; r < N; r++) begin
      for (int c = 0; c < N; c++) begin
        spad_x_write(addr_x(r,c,0), fp(X_mat[r][c]));
      end
    end

    $display("Controller sending data to W_SC");
    // ---- Preload W as identity: contiguous per column ----
    for (int c = 0; c < N; c++) begin
      for (int r = 0; r < N; r++) begin
        spad_w_write(addr_x(r,c,0), fp((r==c) ? 1.0 : 0.0));
      end
    end

    repeat (3) @(posedge clk);
    for (int i = 0; i < N; i++) begin
        pulse_start_once();

        wait (busy === 1'b1);
        wait (busy === 1'b0);

        base_x = base_x + N;
        base_w = base_w + 1;
    end

    repeat ((N)*6) @(posedge clk);

    $display("Controller read data from Y_SC");
    $display("\n---- Result ----");
    for (int j = 0; j < N; j++) begin
        y_index = j;
        for (int i = 0; i < N; i++) begin
            $write("y[%0d,%0d] = %f ", j, i, $bitstoshortreal(y_bus[i]));
        end
        $display();
    end

    repeat (10) @(posedge clk);
    $finish;
  end


endmodule
