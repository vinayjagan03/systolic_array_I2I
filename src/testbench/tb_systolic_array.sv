`include "systolic_array_pkg.svh"

module tb_systolic_array;
    parameter N = 4;
    parameter CLK_PERIOD = 10;

    logic clk, n_rst;
    logic start;
    word_t [N-1:0] x_in;
    word_t [N-1:0] w_in;
    word_t [N-1:0] y_out;
    logic stall;

    systolic_array #(N) dut (
        .clk(clk),
        .n_rst(n_rst),
        .start(start),
        .x_in(x_in),
        .w_in(w_in),
        .y_out(y_out),
        .stall(stall)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer fd;

    // Test sequence
    initial begin
        fd = $fopen("input.bin", "rb");
        if (fd == 0) begin
            $display("Error: Could not open input.bin");
            $finish;
        end

        @(posedge clk);
        // Initialize signals
        n_rst = 0;
        start = 0;
        x_in = '{default:0};
        w_in = '{default:0};

        // Release reset
        @(posedge clk);
        n_rst = 1;
        start = 1;
        $display("Reset released");
        for (int i = 0; i < 2*N + 2; i++) begin
            if (i < 2*N) begin
                $fread(x_in, fd);
                $fread(w_in, fd);
            end else begin
                x_in = 0;
                w_in = 0;
            end
            @(negedge clk);
            while (stall) begin 
                @(posedge clk); 
                @(negedge clk);
            end
            $display("Cycle %0d: x_in = %p, w_in = %p, y_out = %p", i + 1, x_in, w_in, y_out);
            $display("psum reg: %p", dut.psum);
            $display("x: %p", dut.x);
            $display("w: %p", dut.w);
        end
        while (stall) @(posedge clk);
        $fclose(fd);

        fd = $fopen("output_actual.bin", "wb");
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                $display("%p", dut.psum[i][j]);
                $fwrite(fd, "%u", dut.psum[i][j]);
            end
        end
        $fclose(fd);
        $finish;
    end
endmodule