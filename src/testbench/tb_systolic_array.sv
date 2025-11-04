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
    integer cycle_count;

    initial begin
        clk = 0;
        cycle_count = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
        forever @(posedge clk) cycle_count = cycle_count+1;;
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
        for (int i = 0; i < 2*N + N-1; i++) begin
            if (i < 2*N) begin
                $fread(x_in, fd);
                $fread(w_in, fd);
            end else begin
                x_in = 0;
                w_in = 0;
            end
            @(negedge clk);
            @(posedge clk);
            @(negedge clk);
            while (stall) begin 
                @(posedge clk); 
                @(negedge clk);
            end
            $display("\nCycle %0d", i+1);
            $write("x_in: ");
            for (int j = 0; j < N; j++) begin
                $write("%08p ", $bitstoshortreal(x_in[j]));
            end
            $write("\nw_in: ");
            for (int j = 0; j < N; j++) begin
                $write("%08p ", $bitstoshortreal(w_in[j]));
            end
            $write("\nx: ");
            for (int j = 0; j < N*N; j++) begin
                if (j%N == 0) begin
                    $display("");
                end
                $write("%08p ", $bitstoshortreal(dut.x[j / N][j % N]));
            end
            $write("\nw: ");
            for (int j = 0; j < N*N; j++) begin
                if (j%N == 0) begin
                    $display("");
                end
                $write("%08p ", $bitstoshortreal(dut.w[j / N][j % N]));
            end
            $write("\npsum: ");
            for (int j = 0; j < N*N; j++) begin
                if (j%N == 0) begin
                    $display("");
                end
                $write("%08p ", $bitstoshortreal(dut.psum[j / N][j % N]));
            end
            $display("");
            $display("count: %d", dut.row[N-1].col[N-1].pe.count);
        end
        while (stall) @(posedge clk);
        $fclose(fd);

        $display("Cycle count %d", cycle_count);

        fd = $fopen("output_actual.bin", "wb");
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                //$display("%p", $bitstoshortreal(dut.psum[i][j]));
                $fwrite(fd, "%u", dut.psum[i][j]);
            end
        end
        $fclose(fd);
        $finish;
    end
endmodule