`timescale 1ns / 1ps

module iir_wishbone_tb;

  // Parameters
  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 6;

  // Wishbone signals
  reg wb_clk_i;
  reg wb_rst_i;
  reg [ADDR_WIDTH-1:0] wb_adr_i;
  reg [DATA_WIDTH-1:0] wb_dat_i;
  wire [DATA_WIDTH-1:0] wb_dat_o;
  reg wb_we_i;
  reg wb_stb_i;
  reg wb_cyc_i;
  wire wb_ack_o;

  // Instantiate DUT
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

  // Clock generation: 10ns period (100 MHz)
  initial begin
    wb_clk_i = 0;
    forever #5 wb_clk_i = ~wb_clk_i;
  end

  // Variables for file reading
  integer file, r;
  reg signed [DATA_WIDTH-1:0] file_value;
  reg signed [DATA_WIDTH-1:0] read_data;  // Biến lưu dữ liệu đọc từ bus

  // Wishbone write task
  task wishbone_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
  begin
    @(posedge wb_clk_i);
    wb_adr_i <= addr;
    wb_dat_i <= data;
    wb_we_i  <= 1;
    wb_stb_i <= 1;
    wb_cyc_i <= 1;
    wait (wb_ack_o == 1);
    @(posedge wb_clk_i);
    wb_stb_i <= 0;
    wb_cyc_i <= 0;
    wb_we_i  <= 0;
  end
  endtask

  // Wishbone read task
  task wishbone_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
  begin
    @(posedge wb_clk_i);
    wb_adr_i <= addr;
    wb_we_i  <= 0;
    wb_stb_i <= 1;
    wb_cyc_i <= 1;
    wait (wb_ack_o == 1);
    @(posedge wb_clk_i);
    data <= wb_dat_o;
    wb_stb_i <= 0;
    wb_cyc_i <= 0;
  end
  endtask

  // Test sequence
  initial begin
    // Initialize signals
    wb_rst_i = 1;
    wb_adr_i = 0;
    wb_dat_i = 0;
    wb_we_i  = 0;
    wb_stb_i = 0;
    wb_cyc_i = 0;

    // Hold reset for a few cycles
    repeat(5) @(posedge wb_clk_i);
    wb_rst_i = 0;

    // Open input file
    file = $fopen("input_data_chaos.txt", "r");
    if (file == 0) begin
      $display("ERROR: Could not open input_data_chaos.txt");
      $stop;
    end else begin
      $display("File opened successfully.");
    end

    // Read and feed inputs via Wishbone bus
    while (!$feof(file)) begin
      r = $fscanf(file, "%d\n", file_value);
      if (r == 1) begin
        // Write input value to ADDR_X (6'h3C)
        wishbone_write(6'h00, file_value);  // ADDR_X = 0x00

        // Read output value from ADDR_Y (6'h40)
        wishbone_read(6'h04, read_data);  // ADDR_Y = 0x04

        // Display input and output
        $display("Input: %d, Output: %d", file_value, read_data);
      end else begin
        $display("Warning: Failed to read input value");
      end
    end

    $fclose(file);

    // Wait a bit before finishing
    repeat(10) @(posedge wb_clk_i);

    $display("Simulation finished.");
    $stop;
  end

endmodule
