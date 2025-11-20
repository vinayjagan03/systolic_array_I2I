`include "systolic_array_pkg.svh"

module processing_element #(parameter N=4)(
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

    word_t count, next_count;

    fp32_mac u_fp32_mac (
        .clk          (clk),
        .rst_n        (n_rst),
        .valid_in     (start_mac),
        // always 1
        .a            (x_i),
        .b            (w_i),
        .c            (psum_reg),
        .use_acc      (1'b0),
        .clr_acc      (1'b0),
        .valid_out    (fp32_ready),
        .y            (next_fp32_result)
        );

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            current_state <= start;
            psum_reg <= '0;
            fp32_result <= 0;
            x_o <= 0;
            w_o <= 0;
            count <= 0;
        end else begin
            current_state <= next_state;
            psum_reg <= next_psum_reg;
            fp32_result <= next_fp32_result;
            x_o <= (next_state == send) ? x_i : x_o;
            w_o <= (next_state == send) ? w_i : w_o;
            count <= next_count;
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
        partial_sum = psum_reg;
        data_ready = 0;
        stall = 1;
        start_mac = 0;
        next_psum_reg = psum_reg;
        next_count = count;

        case (current_state)
            start: begin
                stall = 1'b0;
                start_mac = input_start;
            end
            mult: begin
                stall = 1'b1;
            end
            send: begin
                partial_sum = next_fp32_result;
                next_psum_reg = next_fp32_result;
                data_ready = 1'b1;
                stall = 1'b0;
                if (input_start)
                    start_mac = 1'b1;
                next_count = count + 1;
            end
        endcase
    end


endmodule