`timescale 1ns / 1ps

module iir_sos_tb;

    parameter DATA_WIDTH = 32;
    parameter COEFF_WIDTH = 32;
    parameter INTERNAL_WIDTH = 64;
    parameter SCALE_SHIFT = 20;

    reg clk;
    reg rst_n;
    reg signed [DATA_WIDTH-1:0] x;
    reg signed [COEFF_WIDTH-1:0] b0, b1, b2, a1, a2;
    wire signed [DATA_WIDTH-1:0] y;

    // Instantiate the Unit Under Test (UUT)
    iir_sos #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .x(x),
        .b0(b0),
        .b1(b1),
        .b2(b2),
        .a1(a1),
        .a2(a2),
        .y(y)
    );

    // Clock generation: 10ns period (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer file, r;
    reg [255:0] line; // buffer for reading line (enough size)
    reg signed [DATA_WIDTH-1:0] file_value;

    initial begin
        // Initialize inputs
        rst_n = 0;
        x = 0;
        b0 = 32'd5509;
        b1 = 32'd11019;
        b2 = 32'd5509;
        a1 = -32'd1998080;
        a2 = 32'd971584;

        // Reset pulse
        #10;
        rst_n = 1;

        // Open file
        file = $fopen("D:/input_data.txt", "r");
        if (file == 0) begin
            $display("ERROR: Could not open input_data.txt");
            $stop;
        end else begin
            $display("File opened successfully.");
        end

        // Read until end of file
        while (!$feof(file)) begin
            r = $fscanf(file, "%d\n", file_value);
            if (r == 1) begin
                x = file_value;
                @(posedge clk); // apply input for one clock cycle
            end else begin
                $display("Warning: Could not read a value properly");
            end
        end

        $fclose(file);

        // Let filter settle for a while
        repeat (20) @(posedge clk);

        $display("Simulation finished.");
        $stop;
    end

    initial begin
        $monitor("Time=%0t clk=%b rst_n=%b x=%d y=%d", $time, clk, rst_n, x, y);
    end

    initial begin
        $dumpfile("iir_sos.vcd");
        $dumpvars(0, iir_sos_tb);
    end

endmodule
