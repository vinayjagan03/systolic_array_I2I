`include "systolic_array_pkg.svh"

module systolic_array_top #(
    parameter N = 64
) (
    input logic clk, n_rst,
    input logic [31:0] x_addr,
    input logic [31:0] w_addr,
    input logic [31:0] y_addr,
    output logic [N-1:0][31:0] sc_x_queue,
    output logic [N-1:0][31:0] sc_w_queue,
    output logic [N-1:0] sc_valid_queue,
    output logic [N-1:0] sc_valid_write,
    output logic [N-1:0][31:0] sc_write_queue,
    output logic [N-1:0][31:0] sc_write_data,
    input [N-1:0][31:0] sc_x_data,
    input [N-1:0][31:0] sc_w_data,
    input logic start_mul,
    output logic stall_mul,
    input logic controller_sc_read_en,
    input logic controller_sc_write_en,
    input logic [31:0] controller_sc_addr,
    output logic [31:0] controller_sc_out,
    input logic [31:0] controller_sc_in
);

    logic start_sys;
    logic [$clog2(N)-1:0] y_index;
    word_t [N-1:0] y_out;
    logic sys_stall;


    logic [$clog2(2*N + N-1)-1:0] counter;
    localparam total_iter = 2*N + N-1; 
    localparam wait_cycles = 6;

    logic [$clog2(N)-1:0] y_ptr;

    logic [2:0] cycle_wait;

    word_t [N-1:0] x_data;
    word_t [N-1:0] w_data;

    systolic_array #(
    .N          (N)
    ) sys_array (
    .clk        (clk),
    .n_rst      (n_rst),
    .start      (start_sys),
    .x_in       (x_data),
    .w_in       (w_data),
    .y_index    (y_index),
    .y_out      (y_out),
    .stall      (sys_stall)
);

    typedef enum logic[3:0] { start, queue, comp, output_arr, finish, controller } state_t;
    state_t state, next_state;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            state <= start;
            counter <= 0;
            cycle_wait <= 0;
            x_data <= 0;
            w_data <= 0;
            y_ptr <= 0;
        end else begin
            state <= next_state;
            counter <= (state == queue) ? counter + 1 : (state == start ? 0 : counter);
            cycle_wait <= (state == comp) ? cycle_wait + 1 : 0;
            x_data <= (state == queue || next_state == queue) ? sc_x_data : x_data;
            w_data <= (state == queue || next_state == queue) ? sc_w_data : w_data;
            y_ptr <= (state == output_arr) ? y_ptr + 1 : 0;
        end
    end

    always_comb begin
        next_state = state;

        case (state)
            start: begin
                if (start_mul)
                    next_state = queue;
                else if (controller_sc_read_en || controller_sc_write_en)
                    next_state = controller;
            end
            queue: begin
                if (counter == total_iter)
                    next_state = output_arr;
                else
                    next_state = comp;
            end
            comp: begin
                if (!sys_stall)
                    next_state = queue;
            end
            output_arr: begin
                if (y_ptr == N-1)
                    next_state = finish;
            end
            finish: next_state = start;
            controller: begin
                if (!(controller_sc_read_en || controller_sc_write_en))
                    next_state = start;
            end
        endcase
    end

    logic [N-1:0][20:0] buffer_counters, next_buffer_counters; 
    logic [N:0] buffer_start, next_buffer_start;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            buffer_counters <= 0;
            buffer_start <= 1;
        end else begin
            buffer_counters <= next_buffer_counters;
            buffer_start <= next_buffer_start;
        end
    end

    always_comb begin
        next_buffer_counters = buffer_counters;
        next_buffer_start = buffer_start;
        sc_valid_queue = 0;
        sc_x_queue = 0;
        sc_w_queue = 0;
        controller_sc_out = 0;
        sc_valid_write = 0;
        sc_write_data = 0;
        y_index = 0;

        if (state == queue) begin
            for (int i = 0; i < N; i++) begin
                if (buffer_counters[i] < N - 1) begin
                    if (i == 0 && buffer_start[i]) begin
                        next_buffer_counters[i] = buffer_counters[i] + 1;
                        next_buffer_start[i + 1] = 1'b1;
                    end else if (buffer_start[i] == 1'b1) begin
                        next_buffer_counters[i] = buffer_counters[i] + 1;
                        next_buffer_start[i + 1] = 1'b1;
                    end
                end else begin
                    next_buffer_start[i] = 1'b0;
                end
            end
        end
        for (int i = 0; i < N; i++) begin
            sc_valid_queue[i] = buffer_start[i];
            sc_x_queue[i] = x_addr + (N -buffer_counters[i] - 1) + ((i) << $clog2(N));
            sc_w_queue[i] = w_addr + i + ((N -buffer_counters[i] - 1) << $clog2(N));
        end
        if (controller_sc_read_en) begin
            sc_valid_queue[0] = 1'b1;
            sc_x_queue[0] = controller_sc_addr;
            controller_sc_out = sc_x_data[0];
        end
        if (controller_sc_write_en) begin
            sc_valid_write[0] = 1'b1;
            sc_write_data[0] = controller_sc_in;
            sc_write_queue[0] = controller_sc_addr;
        end
        if (state == output_arr) begin
            sc_valid_write = ~0;
            y_index = y_ptr;
            sc_write_data = y_out;
            for (int i = 0; i < N; i++) begin
                sc_write_queue[i] = y_addr + (y_ptr << $clog2(N)) + i;
            end
        end

    end

    always_comb begin
        stall_mul = 1'b1;
        start_sys = 1'b1;

        case (state)
            start: begin
                stall_mul = 1'b0;
                start_sys = 1'b0;
            end
            queue: begin
                start_sys = 1'b1;
            end
            comp: begin
                start_sys = 1'b1;
            end
            output_arr: begin
                start_sys = 1'b0;
            end
            finish: begin
                stall_mul = 1'b0;
                start_sys = 1'b0;
            end
            controller: begin
                stall_mul = 1'b0;
                start_sys = 1'b0;
            end
        endcase
    end

endmodule