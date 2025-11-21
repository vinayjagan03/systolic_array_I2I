`include "systolic_array_pkg.svh"

module controller (
    input logic clk, n_rst,
    // Address write signals
    input logic AWVALID,
    input word_t AWADDR,
    output logic AWREADY,
    // Write signals
    input logic WDVALID,
    input word_t WDATA,
    output logic WDREADY,
    // Address read signals
    input logic ARVALID,
    input word_t ARADDR,
    output logic ARREADY,
    // Read signals
    input logic RDREADY,
    output logic RDVALID,
    output word_t RDATA,
    // Scratchpad signals
    output logic sc_read_en,
    output logic sc_write_en,
    output logic sc_data_in,
    input logic sc_data_out,
    output logic sc_addr,
    input logic sc_ready,
    // sys array signals
    output logic start_matmul,
    output word_t input_addr, weight_addr, output_addr,
    input logic matmul_finished
);
    
    typedef enum logic[2:0] { start, sc_read, sc_write, setup_matmul, matmul } state_t;
    state_t state, next_state;

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            state <= start;
            input_addr <= 0;
            weight_addr <= 0;
            output_addr <= 0;
        end else begin
            state <= next_state;
            input_addr <= (state == setup_matmul && AWADDR == 32'hF0000) ? AWADDR : input_addr;
            weight_addr <= (state == setup_matmul && AWADDR == 32'hF0001) ? AWADDR : weight_addr;
            output_addr <= (state == setup_matmul && AWADDR == 32'hF0003) ? AWADDR : output_addr;
        end
    end

    always_comb begin
        next_state = state;

        case (state)
            start: begin
                if (ARVALID)
                    next_state = sc_read;
                else if (AWVALID && AWADDR[23:20] == 0 && AWADDR[19:16] == 4'hF)
                    next_state = setup_matmul;
                else if (AWVALID && AWADDR[23:20] == 4'h1)
                    next_state = matmul;
                else if (AWVALID)
                    next_state = sc_write;
            end
            sc_read: begin
                if (sc_ready) next_state = start;
            end
            sc_write: begin
                if (sc_ready) next_state = start;
            end
            setup_matmul: begin
                next_state = start;
            end
            matmul: begin
                if (matmul_finished) next_state = start;
            end
        endcase
    end

    always_comb begin
        sc_read_en = 1'b0;
        sc_addr = 0;
        ARREADY = 1'b0;
        AWREADY = 1'b0;
        WDREADY = 1'b0;
        start_matmul = 1'b0;

        case (state)
            start: begin
                if (next_state == sc_read) begin
                    ARREADY = 1'b1;
                end
                else if (next_state != start) begin
                    AWREADY = 1'b1;
                end
            end
            sc_read: begin
                sc_read_en = 1'b1;
                sc_addr = ARADDR;
            end
            sc_write: begin
                sc_write_en = 1'b1;
                sc_addr = AWADDR;
                WDREADY = 1'b1;
            end
            setup_matmul: begin
                WDREADY = 1'b1;
            end
            matmul: begin
                start_matmul = 1'b1;
            end
        endcase
    end

endmodule