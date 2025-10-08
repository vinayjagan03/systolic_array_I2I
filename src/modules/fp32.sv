`include "systolic_array_pkg.svh"

module fp32 (
    input logic clk, n_rst,
    input word_t a,
    input word_t b,
    input word_t c,
    input logic start_mac,
    output logic ready,
    output word_t result
);

    typedef enum logic[1:0] { start, mult, add, out } state_t;
    state_t state, next_state;

    word_t mult_a, next_mult_a;
    word_t mult_b, next_mult_b;
    word_t mult_c, next_mult_c;
    word_t mult_out, next_mult_out;
    word_t add_c;
    word_t add_out, next_add_out;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            state <= start;
            mult_a <= '0;
            mult_b <= '0;
            mult_c <= '0;
            mult_out <= '0;
            add_c <= '0;
            add_out <= '0;
        end else begin
            state <= next_state;
            mult_a <= next_mult_a;
            mult_b <= next_mult_b;
            mult_c <= next_mult_c;
            mult_out <= next_mult_out;
            add_c <= mult_c;
            add_out <= next_add_out;

        end
    end

    always_comb begin
        next_state = state;
        ready = 1'b0;

        case (state)
            start: begin
                if (start_mac) begin
                    next_state = mult;
                end
            end
            mult: begin
                next_state = add;
            end
            add: begin
                next_state = out;
            end
            out: begin
                ready = 1'b1;
                next_state = start;
            end
        endcase
    end

    always_comb begin
        next_mult_a = mult_a;
        next_mult_b = mult_b;
        next_mult_c = mult_c;
        next_mult_out = mult_out;
        next_add_out = add_out;
        result = '0;

        case (state)
            start: begin
                if (start_mac) begin
                    next_mult_a = a;
                    next_mult_b = b;
                    next_mult_c = c;
                end
            end
            mult: begin
                next_mult_out = mult_a * mult_b;
            end
            add: begin
                next_add_out = mult_out + add_c;
            end
            out: begin
                result = add_out;
            end
        endcase
    end

endmodule