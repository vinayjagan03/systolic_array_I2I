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

    typedef enum logic[1:0] { start, mult, send } state_t;

    state_t current_state, next_state;

    word_t fp32_result, next_fp32_result;
    logic fp32_ready;
    logic start_mac;
    word_t psum_reg, next_psum_reg;

    fp32 multiplier (
        .clk(clk),
        .n_rst(n_rst),
        .a(x_i),
        .b(w_i),
        .c(psum_reg),
        .start_mac(start_mac),
        .ready(fp32_ready),
        .result(next_fp32_result)
    );

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            current_state <= start;
            psum_reg <= '0;
            fp32_result <= 0;
            x_o <= 0;
            w_o <= 0;
        end else begin
            current_state <= next_state;
            psum_reg <= next_psum_reg;
            fp32_result <= next_fp32_result;
            x_o <= (next_state == send) ? x_i : x_o;
            w_o <= (next_state == send) ? w_i : w_o;
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
        data_ready = 0;
        stall = 1;
        start_mac = 0;
        next_psum_reg = psum_reg;

        case (current_state)
            start: begin
                stall = input_start;
            end
            mult: begin
                stall = 1'b1;
                start_mac = 1'b1;
            end
            send: begin
                next_psum_reg = fp32_result;
                partial_sum = fp32_result; // Output the computed partial sum
                data_ready = 1'b1;
                stall = 1'b0;
            end
        endcase
    end


endmodule