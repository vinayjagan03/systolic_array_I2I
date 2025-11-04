`timescale 1ns/1ps

// Bring in word_t and any shared params/types.
// Use the one you actually have in your repo (.svh vs .sv).
`include "systolic_array_pkg.svh"   // or: `include "systolic_array_pkg.svh"

module tb_sa_spad_top;

  // --------------------- TB parameters ---------------------
  localparam int N  = 4; // number of lanes / SA dimension
  localparam int AW = 6; // SPAD address width (depth = 64)

  // ----------------- DUT interface signals -----------------
  logic clk, n_rst;                  // sim clock & active-low reset
  logic start;                       // 1-cycle pulse → tell top_pd to load+issue
  logic [AW-1:0] base_x, base_w;     // base addresses for the two vectors in SPADs
  logic busy, stall_sa;              // for visibility; not used for control in TB

  // ------------- SPAD port0 (write-only from TB) -----------
  // csb0 is active-LOW per OpenRAM convention.
  logic              spad_x_csb0, spad_w_csb0;
  logic [AW-1:0]     spad_x_addr0, spad_w_addr0;
  word_t             spad_x_din0,  spad_w_din0;

  // ------------------- Observed outputs --------------------
  // Unpacked is TB-friendly and easy to print/probe.
  word_t y_bus [N-1:0];

  // ------------------- DUT instantiation -------------------
  // top_pd does:
  //   * reads N words from SPAD_X and SPAD_W on a start pulse
  //   * latches them, feeds systolic_array once
  //   * exposes SA stall and y_out (unpacked)
  top_pd #(.N(N), .AW(AW)) DUT (
    .clk(clk), .n_rst(n_rst),
    .start_i(start),
    .base_addr_x(base_x),
    .base_addr_w(base_w),
    .busy_o(busy),
    .sa_stall_o(stall_sa),
    .y_out(y_bus),

    // TB-visible write ports
    .spad_x_csb0(spad_x_csb0),
    .spad_x_addr0(spad_x_addr0),
    .spad_x_din0 (spad_x_din0),
    .spad_w_csb0(spad_w_csb0),
    .spad_w_addr0(spad_w_addr0),
    .spad_w_din0 (spad_w_din0)
  );

  // -------------------- Clock & Reset ----------------------
  // 100 MHz clock: period 10 ns
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Reset held low for a few cycles, then released
  initial begin
    n_rst = 1'b0;
    #40 n_rst = 1'b1;
  end

  // -------------------- Waveform dumps ---------------------
  // Dump TB, DUT, and SA hierarchy so you can inspect x/w/y flow and states.
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0);              // TB scope
    $dumpvars(0, DUT);          // top_pd internals
    $dumpvars(0, DUT.U_SA);     // systolic_array + PEs

    // Handy signals to correlate memory reads and loader state
    $dumpvars(0,
      DUT.st_q,                 // loader FSM state
      DUT.idx_q,                // read index (request)
      DUT.csb1_x,               // SPAD_X read enable (active-low)
      DUT.addr1_x,              // SPAD_X read address
      DUT.dout1_x               // SPAD_X read data
    );

    // Uncomment if you want the W-side and SA packed ports too:
    // $dumpvars(0, tb_sa_spad_top.DUT.csb1_w, tb_sa_spad_top.DUT.addr1_w, tb_sa_spad_top.DUT.dout1_w);
    // $dumpvars(0, tb_sa_spad_top.DUT.U_SA.x_in, tb_sa_spad_top.DUT.U_SA.w_in, tb_sa_spad_top.DUT.U_SA.y_out);
  end

  // ----------------- FP32 bit-pattern helper ----------------
  // Convert a real to IEEE-754 single-precision bit pattern (word_t).
  function automatic word_t f2b(input real r);
    shortreal s = r;
    return $shortrealtobits(s);
  endfunction

  // -------------------- Safe write tasks -------------------
  // Writes use *negedge* so they don't race with posedge logic in DUT.
  task automatic spad_write_X(input int addr, input word_t data);
    begin
      spad_x_csb0  = 1'b0;                   // assert (active-low)
      spad_x_addr0 = addr[AW-1:0];
      spad_x_din0  = data;
      @(negedge clk);
      spad_x_csb0  = 1'b1;                   // deassert
      @(negedge clk);                        // spacing between writes
    end
  endtask

  task automatic spad_write_W(input int addr, input word_t data);
    begin
      spad_w_csb0  = 1'b0;
      spad_w_addr0 = addr[AW-1:0];
      spad_w_din0  = data;
      @(negedge clk);
      spad_w_csb0  = 1'b1;
      @(negedge clk);
    end
  endtask

  // ------------------------ Stimulus -----------------------
  initial begin
    // Defaults
    spad_x_csb0 = 1'b1; spad_w_csb0 = 1'b1;  // inactive (high)
    spad_x_addr0 = '0;  spad_w_addr0 = '0;
    spad_x_din0  = '0;  spad_w_din0  = '0;
    start = 1'b0; base_x = '0; base_w = '0;

    // Wait for reset deassertion
    @(posedge n_rst);

    // Keep X and W vectors in different regions for clarity
    base_x = 6'd8;
    base_w = 6'd16;

    // Preload X = [1,2,3,4] into SPAD_X[base_x + i]
    spad_write_X(base_x+0, f2b(1.0));
    spad_write_X(base_x+1, f2b(2.0));
    spad_write_X(base_x+2, f2b(3.0));
    spad_write_X(base_x+3, f2b(4.0));

    // Preload W = [5,6,7,8] into SPAD_W[base_w + i]
    spad_write_W(base_w+0, f2b(5.0));
    spad_write_W(base_w+1, f2b(6.0));
    spad_write_W(base_w+2, f2b(7.0));
    spad_write_W(base_w+3, f2b(8.0));

    // Kick the DUT on a posedge to avoid half-cycle hazards
    @(posedge clk) start = 1'b1;
    @(posedge clk) start = 1'b0;

    // Let it run: covers LOAD_X/LOAD_W, ISSUE, and SA compute
    repeat (200) @(posedge clk);

    // (Optional) print results as floats
    $display("\n===== SA Results =====");
    for (int i = 0; i < N; i++) begin
      $display("y_bus[%0d] = %f", i, $bitstoshortreal(y_bus[i]));
    end

    $finish;
  end

endmodule

