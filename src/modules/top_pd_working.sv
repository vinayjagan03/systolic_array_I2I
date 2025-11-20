// -----------------------------------------------------------------------------
// top_pd.sv — Scratchpad → vector → systolic_array (final, with SETUP & GAP)
//  • TB writes via SPAD port0 (active-low CSB0)
//  • Controller reads via SPAD port1 (active-low CSB1), 1-cycle read latency
//  • Single drivers for CSB/ADDR ( *_d → *_q )
//  • Read data captured on negedge; GAP gives 1 safe cycle before start
//  • Adapters match systolic_array packed 2-D ports: logic [(N-1):0][31:0]
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "systolic_array_pkg.svh"
//import  systolic_array_pkg::*;   // for word_t etc.

module top_pd #(
  parameter int N  = 4,
  parameter int AW = 6,    // 64-deep SPAD → log2(64)=6
  parameter int DW = 32
)(
  input  logic              clk,
  input  logic              n_rst,          // active-high
  input  logic              start_i,        // 1-cycle pulse (host)
  input  logic [AW-1:0]     base_addr_x,    // start of desired X row (row_major)
  input  logic [AW-1:0]     base_addr_w,    // start of desired W col (col_major)
  output logic              busy_o,
  output logic              sa_stall_o,
  output logic [DW-1:0]     y_out [N-1:0],
  input  logic [$clog2(N)-1:0] y_index,

  // -------- TB preload port (WRITE, port0) for each scratchpad (active-low) ---
  input  logic              spad_x_csb0,
  input  logic [AW-1:0]     spad_x_addr0,
  input  logic [DW-1:0]     spad_x_din0,

  input  logic              spad_w_csb0,
  input  logic [AW-1:0]     spad_w_addr0,
  input  logic [DW-1:0]     spad_w_din0,

  input  logic              spad_y_csb1,
  input  logic [AW-1:0]     spad_y_addr1,
  input  logic [DW-1:0]     spad_y_dout1

);

  logic [3:0] delay, next_delay;

  // ----------------------------- Scratchpads ---------------------------------
  // Port1 READ controls (registered, single driver). Model uses (!csb1).
  logic              csb1_x_q, csb1_w_q;     // 0 = enabled, 1 = idle
  logic [AW-1:0]     addr1_x_q, addr1_w_q;
  logic [DW-1:0]     dout1_x,   dout1_w;

  logic csb0_y_q;
  logic [AW-1:0] addr0_y_q;
  logic [DW-1:0] din0_y;

  sram_0rw1r1w_32_64_freepdk45 SPAD_X (
    .clk0 (clk), .csb0(spad_x_csb0), .addr0(spad_x_addr0), .din0(spad_x_din0),
    .clk1 (clk), .csb1(csb1_x_q),    .addr1(addr1_x_q),    .dout1(dout1_x)
  );

  sram_0rw1r1w_32_64_freepdk45 SPAD_W (
    .clk0 (clk), .csb0(spad_w_csb0), .addr0(spad_w_addr0), .din0(spad_w_din0),
    .clk1 (clk), .csb1(csb1_w_q),    .addr1(addr1_w_q),    .dout1(dout1_w)
  );

  sram_0rw1r1w_32_64_freepdk45 SPAD_Y (
    .clk0 (clk), .csb0(csb0_y_q), .addr0(addr0_y_q), .din0(din0_y),
    .clk1 (clk), .csb1(spad_y_csb1), .addr1(spad_y_addr1), .dout1(spad_y_dout1)
  );

  // ------------------------------ Local storage ------------------------------
  logic [DW-1:0] x_vec [N-1:0];
  logic [DW-1:0] w_vec [N-1:0];

  // Pack/unpack for systolic_array ports (packed 2-D)
  logic [N-1:0][DW-1:0] x_pack_p, w_pack_p, y_pack_p;
  genvar i;
  generate
    for (i = 0; i < N; i++) begin : G_ADAPT
      assign x_pack_p[i] = x_vec[i];   // if SA expects reversed order, flip here
      assign w_pack_p[i] = w_vec[i];
      assign y_out[i]    = y_pack_p[i];
    end
  endgenerate

  // ------------------------------- Loader FSM --------------------------------
  typedef enum logic [2:0] { IDLE, SETUP_X, LOAD_X, SETUP_W, LOAD_W, GAP, ISSUE } state_t;
  state_t st_q, st_next;

  logic [AW-1:0] idx_q, idx_next;      // 0..N-1

  // Next/read control (registered to *_q)
  logic              csb1_x_d, csb1_w_d;
  logic [AW-1:0]     addr1_x_d, addr1_w_d;

  // Read-valid pipeline & capture index (for 1-cycle SPAD latency)
  logic              rd_vld_x_q, rd_vld_x_d;
  logic              rd_vld_w_q, rd_vld_w_d;
  logic [AW-1:0]     cap_idx_x_q, cap_idx_x_d;
  logic [AW-1:0]     cap_idx_w_q, cap_idx_w_d;

  // Busy & SA start pulse
  logic busy_q, busy_d;  assign busy_o = busy_q;
  logic sa_start_q, sa_start_d;

  // Address helpers: contiguous N words from bases
  function automatic [AW-1:0] addr_x(input [AW-1:0] i);
    return base_addr_x + i;    // X row start at base_addr_x
  endfunction
  function automatic [AW-1:0] addr_w(input [AW-1:0] i);
    return base_addr_w + i * N;    // W column start at base_addr_w
  endfunction

  // ----------------------------- Next-state logic ----------------------------
  always_comb begin
    // defaults
    st_next       = st_q;
    idx_next      = idx_q;

    csb1_x_d      = 1'b1;   addr1_x_d = '0;   // active-low: 1 = idle
    csb1_w_d      = 1'b1;   addr1_w_d = '0;

    rd_vld_x_d    = 1'b0;   rd_vld_w_d = 1'b0;
    cap_idx_x_d   = cap_idx_x_q;
    cap_idx_w_d   = cap_idx_w_q;

    busy_d        = busy_q;
    sa_start_d    = 1'b0;

    next_delay = delay;

    unique case (st_q)
      IDLE: begin
        busy_d = 1'b0;
        if (start_i) begin
          st_next  = SETUP_X;          // assert CSB one beat early
          idx_next = '0;
          busy_d   = 1'b1;
        end
      end

      // --- X vector ---
      SETUP_X: begin
        csb1_x_d    = 1'b0;
        addr1_x_d   = addr_x(idx_q);
        rd_vld_x_d  = 1'b0;            // no capture this beat
        cap_idx_x_d = idx_q;
        st_next     = LOAD_X;
        next_delay = 0;
      end

      LOAD_X: begin
        csb1_x_d    = 1'b0;            // keep enabled entire burst
        addr1_x_d   = addr_x(idx_q);
        rd_vld_x_d  = 1'b1;            // capture next negedge
        cap_idx_x_d = idx_q;

        if (delay == 3) begin
            if (idx_q == N-1) begin
                st_next  = SETUP_W;
                idx_next = '0;
            end else begin
                idx_next = idx_q + 1;
            end
        end

        next_delay = delay + 1;
      end

      // --- W vector ---
      SETUP_W: begin
        csb1_w_d    = 1'b0;
        addr1_w_d   = addr_w(idx_q);
        rd_vld_w_d  = 1'b0;
        cap_idx_w_d = idx_q;
        st_next     = LOAD_W;
        next_delay = 0;
      end

      LOAD_W: begin
        csb1_w_d    = 1'b0;            // keep enabled entire burst
        addr1_w_d   = addr_w(idx_q);
        rd_vld_w_d  = 1'b1;
        cap_idx_w_d = idx_q;

        if (delay == 3) begin
            if (idx_q == N-1) begin
                st_next  = GAP;              // keep CSBs low through gap
                idx_next = '0;
            end else begin
                idx_next = idx_q + 1;
            end
        end

        next_delay = delay + 1;
      end

      GAP: begin
        csb1_x_d    = 1'b0;            // hold low so dout stays stable
        csb1_w_d    = 1'b0;
        st_next     = ISSUE;
      end

      ISSUE: begin
        sa_start_d  = 1'b1;            // one clean cycle
        csb1_x_d    = 1'b1;            // can release now
        csb1_w_d    = 1'b1;
        busy_d      = 1'b0;
        st_next     = IDLE;
      end
    endcase
  end

  // ------------------------------- State flops -------------------------------
  always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
      st_q        <= IDLE;
      idx_q       <= '0;

      csb1_x_q    <= 1'b1;  addr1_x_q <= '0;   // idle
      csb1_w_q    <= 1'b1;  addr1_w_q <= '0;

      rd_vld_x_q  <= 1'b0;  rd_vld_w_q <= 1'b0;
      cap_idx_x_q <= '0;    cap_idx_w_q <= '0;

      busy_q      <= 1'b0;
      sa_start_q  <= 1'b0;
      delay <= 0;
    end else begin
      st_q        <= st_next;
      idx_q       <= idx_next;

      csb1_x_q    <= csb1_x_d;  addr1_x_q <= addr1_x_d;
      csb1_w_q    <= csb1_w_d;  addr1_w_q <= addr1_w_d;

      rd_vld_x_q  <= rd_vld_x_d;
      rd_vld_w_q  <= rd_vld_w_d;
      cap_idx_x_q <= cap_idx_x_d;
      cap_idx_w_q <= cap_idx_w_d;

      busy_q      <= busy_d;
      sa_start_q  <= sa_start_d;
      delay <= next_delay;
    end
  end

  // -------- Capture read data on negedge (avoids same-edge address race) -----
  always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst) begin
      for (int k = 0; k < N; k++) begin
        x_vec[k] <= '0;
        w_vec[k] <= '0;
      end
    end else begin
      if (st_q == LOAD_X && rd_vld_x_q) x_vec[cap_idx_x_q] <= dout1_x;
      if (st_q == LOAD_W && rd_vld_w_q) w_vec[cap_idx_w_q] <= dout1_w;
    end
  end

  // ---------------------------- Systolic array -------------------------------
  systolic_array #(.N(N)) U_SA (
    .clk  (clk),
    .n_rst(n_rst),
    .start(sa_start_q),
    .x_in (x_pack_p),   // logic [(N-1):0][31:0]
    .w_in (w_pack_p),
    .y_index(y_index),
    .y_out(y_pack_p),
    .stall(sa_stall_o)
  );

endmodule
