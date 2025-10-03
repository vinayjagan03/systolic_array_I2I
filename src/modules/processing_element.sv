`include "systolic_array_pkg.svh"

module processing_element (
    input logic clk, n_rst,
    input word_t x_i,
    input word_t w_i,
    input logic input_start,
    output word_t partial_sum,
    output word_t x_o,
    output word_t w_o,
    output logic data_ready,
    output logic stall
);

    typedef enum logic[1:0] { start, mult, sum, send } state_t;

    state_t current_state, next_state;

    word_t fp32_result;
    logic fp32_ready;
    logic start_mac;

    fp32 multiplier (
        .clk(clk),
        .n_rst(n_rst),
        .a(x_i),
        .b(w_i),
        .c(psum_reg),
        .start_mac(start_mac),
        .ready(fp32_ready),
        .result(fp32_result)
    );

    word_t psum_reg, next_psum_reg;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            current_state <= start;
            psum_reg <= '0;
        end else begin
            current_state <= next_state;
            psum_reg <= next_psum_reg;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            start: begin
                if (input_start) begin
                    next_state = mult;
                end
            end
            mult: begin
                if (fp32_ready)
                    next_state = sum;
            end
            sum: begin
                next_state = send;
            end
            send: begin
                if (input_start)
                    next_state = mult;
                else
                    next_state = start;
            end
            default: begin
                next_state = start;
            end
        endcase
    end

    always_comb begin
        partial_sum = 0;
        x_o = x_i;
        w_o = w_i;
        data_ready = 0;
        stall = 1;

        case (current_state)
            start: begin
                stall = 1'b0;
            end
            mult: begin
                stall = 1'b1;
            end
            sum: begin
                stall = 1'b1;
            end
            send: begin
                partial_sum = mult_result; // Output the computed partial sum
                data_ready = 1'b1;
                stall = 1'b0;
            end
            default: begin
                stall = 1'b0;
            end
        endcase
    end


endmodule