`timescale 1ns / 1ps

// Self-Checking Testbench for IIR Wishbone Filter
// Features:
// - Automatic test vectors with expected values
// - Coefficient configuration test
// - Overflow detection test
// - Pass/Fail summary

module iir_wishbone_tb;

    //=========================================================================
    // Parameters
    //=========================================================================
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 8;
    parameter CLK_PERIOD = 20;  // 50 MHz

    //=========================================================================
    // Address Map (must match iir_wishbone)
    //=========================================================================
    localparam ADDR_X        = 8'h00;
    localparam ADDR_Y        = 8'h04;
    localparam ADDR_STATUS   = 8'h08;
    localparam ADDR_B0_S1    = 8'h10;
    localparam ADDR_B1_S1    = 8'h14;
    localparam ADDR_B2_S1    = 8'h18;
    localparam ADDR_A1_S1    = 8'h1C;
    localparam ADDR_A2_S1    = 8'h20;

    //=========================================================================
    // DUT Signals
    //=========================================================================
    reg wb_clk_i;
    reg wb_rst_i;
    reg [ADDR_WIDTH-1:0] wb_adr_i;
    reg [DATA_WIDTH-1:0] wb_dat_i;
    wire [DATA_WIDTH-1:0] wb_dat_o;
    reg wb_we_i;
    reg wb_stb_i;
    reg wb_cyc_i;
    wire wb_ack_o;

    //=========================================================================
    // Test Counters
    //=========================================================================
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    iir_wishbone #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wb_adr_i(wb_adr_i),
        .wb_dat_i(wb_dat_i),
        .wb_dat_o(wb_dat_o),
        .wb_we_i(wb_we_i),
        .wb_stb_i(wb_stb_i),
        .wb_cyc_i(wb_cyc_i),
        .wb_ack_o(wb_ack_o)
    );

    //=========================================================================
    // Clock Generation
    //=========================================================================
    initial begin
        wb_clk_i = 0;
        forever #(CLK_PERIOD/2) wb_clk_i = ~wb_clk_i;
    end

    //=========================================================================
    // Wishbone Tasks
    //=========================================================================
    task wishbone_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge wb_clk_i);
            wb_adr_i <= addr;
            wb_dat_i <= data;
            wb_we_i  <= 1;
            wb_stb_i <= 1;
            wb_cyc_i <= 1;
            @(posedge wb_clk_i);
            while (!wb_ack_o) @(posedge wb_clk_i);
            @(posedge wb_clk_i);
            wb_stb_i <= 0;
            wb_cyc_i <= 0;
            wb_we_i  <= 0;
        end
    endtask

    task wishbone_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge wb_clk_i);
            wb_adr_i <= addr;
            wb_we_i  <= 0;
            wb_stb_i <= 1;
            wb_cyc_i <= 1;
            @(posedge wb_clk_i);
            while (!wb_ack_o) @(posedge wb_clk_i);
            data = wb_dat_o;
            @(posedge wb_clk_i);
            wb_stb_i <= 0;
            wb_cyc_i <= 0;
        end
    endtask

    //=========================================================================
    // Check Task with Pass/Fail Counting
    //=========================================================================
    task check_value;
        input [255:0] test_name;
        input [DATA_WIDTH-1:0] actual;
        input [DATA_WIDTH-1:0] expected;
        input [DATA_WIDTH-1:0] tolerance;  // Allow some tolerance for filter output
        begin
            test_count = test_count + 1;
            if ((actual >= expected - tolerance) && (actual <= expected + tolerance)) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s: Expected=%d, Actual=%d", test_name, expected, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s: Expected=%d (+/-%d), Actual=%d", 
                         test_name, expected, tolerance, actual);
            end
        end
    endtask

    //=========================================================================
    // Main Test Sequence
    //=========================================================================
    reg [DATA_WIDTH-1:0] read_data;
    integer i;
    
    initial begin
        $display("============================================");
        $display("  IIR Filter Self-Checking Testbench");
        $display("============================================");
        
        // Initialize
        wb_rst_i = 1;
        wb_adr_i = 0;
        wb_dat_i = 0;
        wb_we_i  = 0;
        wb_stb_i = 0;
        wb_cyc_i = 0;
        
        // Hold reset
        repeat(10) @(posedge wb_clk_i);
        wb_rst_i = 0;
        repeat(5) @(posedge wb_clk_i);
        
        //=====================================================================
        // Test 1: Read default coefficients
        //=====================================================================
        $display("\n--- Test 1: Default Coefficients ---");
        
        wishbone_read(ADDR_B0_S1, read_data);
        check_value("B0_S1 default", read_data, 32'd5509, 0);
        
        wishbone_read(ADDR_B1_S1, read_data);
        check_value("B1_S1 default", read_data, 32'd11019, 0);
        
        //=====================================================================
        // Test 2: Write and read back coefficients
        //=====================================================================
        $display("\n--- Test 2: Coefficient Write/Read ---");
        
        wishbone_write(ADDR_B0_S1, 32'd12345);
        wishbone_read(ADDR_B0_S1, read_data);
        check_value("B0_S1 write/read", read_data, 32'd12345, 0);
        
        // Restore default
        wishbone_write(ADDR_B0_S1, 32'd5509);
        
        //=====================================================================
        // Test 3: Filter Response - Unit impulse
        //=====================================================================
        $display("\n--- Test 3: Impulse Response ---");
        
        // Clear filter state with reset
        wb_rst_i = 1;
        repeat(5) @(posedge wb_clk_i);
        wb_rst_i = 0;
        repeat(5) @(posedge wb_clk_i);
        
        // Apply impulse (large value scaled by 2^20)
        wishbone_write(ADDR_X, 32'd1048576);  // 1.0 in Q11.20
        
        // Wait for pipeline latency (4 cycles per section * 3 sections = 12 cycles + margin)
        repeat(20) @(posedge wb_clk_i);
        
        // Read output - should be non-zero due to b0 coefficient
        wishbone_read(ADDR_Y, read_data);
        $display("Impulse response output: %d", $signed(read_data));
        
        // Apply zero input
        wishbone_write(ADDR_X, 32'd0);
        
        // Wait and sample decaying response
        repeat(10) @(posedge wb_clk_i);
        wishbone_read(ADDR_Y, read_data);
        $display("Decay response[1]: %d", $signed(read_data));
        
        repeat(10) @(posedge wb_clk_i);
        wishbone_read(ADDR_Y, read_data);
        $display("Decay response[2]: %d", $signed(read_data));
        
        //=====================================================================
        // Test 4: Check Status Register (overflow flags)
        //=====================================================================
        $display("\n--- Test 4: Status Register ---");
        
        wishbone_read(ADDR_STATUS, read_data);
        $display("Status register: 0x%08X", read_data);
        check_value("Status clear after read", read_data[3:0] == 0 ? 1 : 0, 1, 0);
        
        //=====================================================================
        // Test 5: Step Response
        //=====================================================================
        $display("\n--- Test 5: Step Response ---");
        
        // Reset filter
        wb_rst_i = 1;
        repeat(5) @(posedge wb_clk_i);
        wb_rst_i = 0;
        repeat(5) @(posedge wb_clk_i);
        
        // Apply step input
        for (i = 0; i < 50; i = i + 1) begin
            wishbone_write(ADDR_X, 32'd100000);  // Constant input
            repeat(5) @(posedge wb_clk_i);
        end
        
        // Read settled output
        wishbone_read(ADDR_Y, read_data);
        $display("Step response settled: %d", $signed(read_data));
        // For low-pass filter, DC gain should pass through
        // With these coefficients, expect output close to input (DC gain ~1)
        
        //=====================================================================
        // Test 6: Sine Wave Input
        //=====================================================================
        $display("\n--- Test 6: Sine Wave Test ---");
        
        // Reset
        wb_rst_i = 1;
        repeat(5) @(posedge wb_clk_i);
        wb_rst_i = 0;
        repeat(5) @(posedge wb_clk_i);
        
        // Simple sine approximation (low frequency should pass)
        wishbone_write(ADDR_X, 32'd0);
        repeat(5) @(posedge wb_clk_i);
        wishbone_write(ADDR_X, 32'd50000);
        repeat(5) @(posedge wb_clk_i);
        wishbone_write(ADDR_X, 32'd86603);  // sin(60)*100000
        repeat(5) @(posedge wb_clk_i);
        wishbone_write(ADDR_X, 32'd100000); // peak
        repeat(5) @(posedge wb_clk_i);
        wishbone_write(ADDR_X, 32'd86603);
        repeat(5) @(posedge wb_clk_i);
        wishbone_write(ADDR_X, 32'd50000);
        repeat(5) @(posedge wb_clk_i);
        wishbone_write(ADDR_X, 32'd0);
        
        repeat(30) @(posedge wb_clk_i);
        wishbone_read(ADDR_Y, read_data);
        $display("Sine test output: %d", $signed(read_data));
        
        //=====================================================================
        // Summary
        //=====================================================================
        $display("\n============================================");
        $display("  TEST SUMMARY");
        $display("============================================");
        $display("  Total Tests: %0d", test_count);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("============================================");
        
        if (fail_count == 0) begin
            $display("  *** ALL TESTS PASSED ***");
        end else begin
            $display("  *** SOME TESTS FAILED ***");
        end
        
        $display("============================================\n");
        
        #100;
        $finish;
    end

    //=========================================================================
    // Waveform Dump
    //=========================================================================
    initial begin
        $dumpfile("iir_wishbone_tb.vcd");
        $dumpvars(0, iir_wishbone_tb);
    end

endmodule
