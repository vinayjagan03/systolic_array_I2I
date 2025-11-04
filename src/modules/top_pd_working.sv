// -----------------------------------------------------------------------------
// top_pd.sv — Simple scratchpad→vector→systolic_array integration
//  - Preload SPAD_X / SPAD_W via port0 from the testbench
//  - On start_i, read N words from each SPAD on port1
//  - Capture OpenRAM read data with a 1-cycle latency on the *negedge* of clk
//  - After both vectors are captured, drive the systolic_array once
//  - No fancy flow control; sa_stall_o is just exposed from the array
// -----------------------------------------------------------------------------
// Notes on OpenRAM-style models used here:
//   • 1R latency on read port: addr presented on cycle T → data valid on T+1
//   • Using negedge capture avoids same-edge read/capture races in sim
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "systolic_array_pkg.svh"

module top_pd #(
  parameter int N  = 4,   // array dimension (N lanes)
  parameter int AW = 6,   // SPAD address width (depth = 2^AW)
  parameter int DW = 32   // data width (FP32)
)(
  input  logic clk,
  input  logic n_rst,          // active-low reset
  input  logic start_i,        // 1-cycle pulse to kick off a load+issue
  input  logic [AW-1:0] base_addr_x, // base address of X vector in SPAD_X
  input  logic [AW-1:0] base_addr_w, // base address of W vector in SPAD_W
  output logic busy_o,         // simple "busy while loading/issuing" indicator
  output logic sa_stall_o,     // stall propagated from systolic_array
  output logic [DW-1:0] y_out [N-1:0], // unpacked outputs (easy to probe)

  // ---------------- Testbench-visible SPAD write ports (port0) --------------
  // The TB uses these to preload the two scratchpads before asserting start_i.
  input  logic              spad_x_csb0, // active-low chip select for SPAD_X port0
  input  logic [AW-1:0]     spad_x_addr0,
  input  logic [DW-1:0]     spad_x_din0,
  input  logic              spad_w_csb0, // active-low chip select for SPAD_W port0
  input  logic [AW-1:0]     spad_w_addr0,
  input  logic [DW-1:0]     spad_w_din0
);

  // ----------------------------- Scratchpads ---------------------------------
  // Port1 is dedicated to READS the design performs during LOAD_X/LOAD_W.
  // OpenRAM convention: csb*_x/csb*_w are active-LOW.
  logic              csb1_x, csb1_w;
  logic [AW-1:0]     addr1_x, addr1_w;
  logic [DW-1:0]     dout1_x, dout1_w;

  sram_0rw1r1w_32_64_freepdk45 SPAD_X (
    .clk0 (clk), .csb0(spad_x_csb0), .addr0(spad_x_addr0), .din0(spad_x_din0),
    .clk1 (clk), .csb1(csb1_x),      .addr1(addr1_x),      .dout1(dout1_x)
  );
  sram_0rw1r1w_32_64_freepdk45 SPAD_W (
    .clk0 (clk), .csb0(spad_w_csb0), .addr0(spad_w_addr0), .din0(spad_w_din0),
    .clk1 (clk), .csb1(csb1_w),      .addr1(addr1_w),      .dout1(dout1_w)
  );

  logic [4:0] delay, next_delay;

  // ------------------ Staging vectors and pack/unpack bridges ----------------
  // x_vec / w_vec: temporary storage filled during LOAD_X / LOAD_W
  logic [DW-1:0] x_vec [N-1:0];
  logic [DW-1:0] w_vec [N-1:0];

  // x_in_unpacked / w_in_unpacked: what we finally feed into the SA
  logic [DW-1:0] x_in_unpacked [N-1:0];
  logic [DW-1:0] w_in_unpacked [N-1:0];

  // The systolic_array’s ports are PACKED 2D: [N-1:0][DW-1:0].
  // These shims map our unpacked arrays into packed form (and back for y_out).
  logic [N-1:0][DW-1:0] x_in_packed, w_in_packed, y_out_packed;

  genvar gi;
  generate
    for (gi = 0; gi < N; gi++) begin : PACK_ADAPTERS
      // Unpacked → packed (inputs to SA)
      always_comb x_in_packed[gi] = x_in_unpacked[gi];
      always_comb w_in_packed[gi] = w_in_unpacked[gi];
      // Packed → unpacked (outputs from SA)
      always_comb y_out[gi]       = y_out_packed[gi];
    end
  endgenerate

  // ---------------- Loader "FSM" with explicit 1-cycle read pipeline ---------
  //  IDLE  : wait for start_i
  //  LOAD_X: issue N reads from SPAD_X (port1); capture on negedge with 1-cycle latency
  //  LOAD_W: same for SPAD_W
  //  ISSUE : one-cycle pulse to systolic_array.start (sa_start_q)
  typedef enum logic [1:0] {IDLE, LOAD_X, LOAD_W, ISSUE} state_t;
  state_t st_q, st_d;

  // idx_q: "request" index used to *issue* reads; runs 0..N-1
  logic [AW-1:0] idx_q, idx_d;

  // rd_vld_*_q: becomes 1 after the very first read is issued, so we skip
  //             capturing garbage on the first cycle (warm-up bubble)
  // cap_idx_*_q: which element we will capture *this* negedge (lagging idx_q by 1)
  logic               rd_vld_x_q, rd_vld_x_d;
  logic               rd_vld_w_q, rd_vld_w_d;
  logic [AW-1:0] cap_idx_x_q, cap_idx_x_d;
  logic [AW-1:0] cap_idx_w_q, cap_idx_w_d;

  // sa_start_q is registered and connected to SA.start
  logic sa_start_q, sa_start_d;

  // ---------------------------- Read-port driving ----------------------------
  // Assert read enables only in their respective states.
  assign csb1_x  = (st_q == LOAD_X) ? 1'b0 : 1'b1; // active-low
  assign csb1_w  = (st_q == LOAD_W) ? 1'b0 : 1'b1; // active-low

  // Linear addressing: base_addr + idx_q (issuing reads 0..N-1)
  assign addr1_x = base_addr_x + idx_q[AW-1:0];
  assign addr1_w = base_addr_w + idx_q[AW-1:0];

  // "Busy" when not idle OR when the SA claims stall (simple exposure)
  assign busy_o  = (st_q != IDLE) | sa_stall_o;

  // ------------------------------- Next-state --------------------------------
  always_comb begin
    st_d        = st_q;
    idx_d       = idx_q;
    sa_start_d  = 1'b0;        // default: no start pulse

    // By default, hold these pipeline flags/indices unless state dictates
    rd_vld_x_d  = rd_vld_x_q;
    rd_vld_w_d  = rd_vld_w_q;
    cap_idx_x_d = cap_idx_x_q;
    cap_idx_w_d = cap_idx_w_q;
    next_delay = delay;

    unique case (st_q)
      IDLE: begin
        if (start_i) begin
          // Begin X read sequence; initialize bubble for 1R latency
          st_d        = LOAD_X;
          idx_d       = '0;
          rd_vld_x_d  = 1'b0;  // first cycle: do not capture
          cap_idx_x_d = '0;    // next negedge will capture into element 0
          next_delay = 0;
        end
      end

      LOAD_X: begin
        // Issue read for current idx_q on this cycle
        // Negedge process below will capture the *previous* request
        if (delay == 3) begin
            if (idx_q == N-1) begin
                // Last request issued → transition to LOAD_W, reinit W bubble
                st_d        = LOAD_W;
                idx_d       = '0;
                rd_vld_w_d  = 1'b0;
                cap_idx_w_d = '0;
            end else begin
                idx_d = idx_q + 1;
            end
            next_delay = 0;
        end else begin
            next_delay = delay + 1;
        end
      end

      LOAD_W: begin
        if (delay == 3) begin
        if (idx_q == N-1) begin
          // All W reads issued; next cycle we’ll *issue* SA start
          st_d       = ISSUE;
        end else begin
          idx_d = idx_q + 1;
        end
            next_delay = 0;
        end else begin
            next_delay = delay + 1;
        end
      end

      ISSUE: begin
        // Single-cycle start pulse to the systolic_array
        sa_start_d = 1'b1;
        st_d       = IDLE;
      end
    endcase
  end

  // ---------------- Negedge capture (1-cycle delayed) -----------------------
  // We purposely capture on the *falling* edge to avoid races with addr changes
  // on posedge and to model the 1R latency behavior cleanly in simulation.
  always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
      rd_vld_x_q  <= 1'b0;
      rd_vld_w_q  <= 1'b0;
      cap_idx_x_q <= '0;
      cap_idx_w_q <= '0;
      // Clear staging vectors
      for (int i = 0; i < N; i++) begin
        x_vec[i] <= '0;
        w_vec[i] <= '0;
      end
      delay <= 0;
    end else begin
      // LOAD_X: capture valid dout1_x into x_vec[cap_idx_x_q]
      if (st_q == LOAD_X) begin
        if (rd_vld_x_q && delay == 2) x_vec[cap_idx_x_q] <= dout1_x; // capture previous req
        rd_vld_x_q  <= 1'b1;                            // bubble cleared
        cap_idx_x_q <= idx_q;                           // next capture index
      end else begin
        rd_vld_x_q  <= 1'b0;                            // not capturing
      end

      // LOAD_W: symmetric to X
      if (st_q == LOAD_W) begin
        if (rd_vld_w_q) w_vec[cap_idx_w_q] <= dout1_w;
        rd_vld_w_q  <= 1'b1;
        cap_idx_w_q <= idx_q;
      end else begin
        rd_vld_w_q  <= 1'b0;
      end

      delay <= next_delay;
    end
  end

  // ---------------- Posedge state/commit + handoff to SA --------------------
  always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
      st_q       <= IDLE;
      idx_q      <= '0;
      sa_start_q <= 1'b0;
      // Clear the SA input latches
      for (int i = 0; i < N; i++) begin
        x_in_unpacked[i] <= '0;
        w_in_unpacked[i] <= '0;
      end
    end else begin
      st_q       <= st_d;
      idx_q      <= idx_d;
      sa_start_q <= sa_start_d;

      // When LOAD_W → ISSUE, both x_vec and w_vec are fully populated
      // Commit them into the SA input latches in one shot.
      if (st_q == LOAD_W && st_d == ISSUE) begin
        for (int i = 0; i < N; i++) begin
          x_in_unpacked[i] <= x_vec[i];
          w_in_unpacked[i] <= w_vec[i];
        end
      end
    end
  end

  // ---------------------------- Systolic Array -------------------------------
  // Simple fire-once behavior: when sa_start_q pulses, the array consumes
  // x_in_packed / w_in_packed and produces y_out_packed. No back-pressure is
  // implemented here; sa_stall_o is just exposed from the array.
  systolic_array #(.N(N)) U_SA (
    .clk  (clk),
    .n_rst(n_rst),
    .start(sa_start_q),
    .x_in (x_in_packed),
    .w_in (w_in_packed),
    .y_out(y_out_packed),
    .stall(sa_stall_o)
  );

endmodule
