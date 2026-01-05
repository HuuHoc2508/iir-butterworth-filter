// IIR Filter with Wishbone Interface
// Features:
// - Configurable coefficients via Wishbone
// - Overflow detection and status register
// - Pipeline architecture for high Fmax

module iir_wishbone #(
    parameter DATA_WIDTH = 32,
    parameter COEFF_WIDTH = 32,
    parameter INTERNAL_WIDTH = 64,
    parameter SCALE_SHIFT = 20,
    parameter ADDR_WIDTH = 8  // Extended to 8-bit for more registers
) (
    // Wishbone interface
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire wb_we_i,
    input wire wb_stb_i,
    input wire wb_cyc_i,
    output reg wb_ack_o
);

    //=========================================================================
    // Address Map (8-bit address space: 0x00-0xFF)
    //=========================================================================
    // Control & Status
    localparam ADDR_X        = 8'h00;  // Input sample (R/W)
    localparam ADDR_Y        = 8'h04;  // Output sample (R)
    localparam ADDR_STATUS   = 8'h08;  // Status register (R) - overflow flags
    localparam ADDR_CONTROL  = 8'h0C;  // Control register (R/W) - reserved
    
    // Section 1 Coefficients (0x10-0x20)
    localparam ADDR_B0_S1    = 8'h10;
    localparam ADDR_B1_S1    = 8'h14;
    localparam ADDR_B2_S1    = 8'h18;
    localparam ADDR_A1_S1    = 8'h1C;
    localparam ADDR_A2_S1    = 8'h20;
    
    // Section 2 Coefficients (0x24-0x34)
    localparam ADDR_B0_S2    = 8'h24;
    localparam ADDR_B1_S2    = 8'h28;
    localparam ADDR_B2_S2    = 8'h2C;
    localparam ADDR_A1_S2    = 8'h30;
    localparam ADDR_A2_S2    = 8'h34;
    
    // Section 3 Coefficients (0x38-0x48)
    localparam ADDR_B0_S3    = 8'h38;
    localparam ADDR_B1_S3    = 8'h3C;
    localparam ADDR_B2_S3    = 8'h40;
    localparam ADDR_A1_S3    = 8'h44;
    localparam ADDR_A2_S3    = 8'h48;

    //=========================================================================
    // Coefficient Registers (configurable via Wishbone)
    //=========================================================================
    // Default values for Butterworth Low-Pass Filter (Q11.20 format)
    reg signed [COEFF_WIDTH-1:0] b0_s1, b1_s1, b2_s1, a1_s1, a2_s1;
    reg signed [COEFF_WIDTH-1:0] b0_s2, b1_s2, b2_s2, a1_s2, a2_s2;
    reg signed [COEFF_WIDTH-1:0] b0_s3, b1_s3, b2_s3, a1_s3, a2_s3;

    // Input/Output registers
    reg signed [DATA_WIDTH-1:0] x_reg;
    wire signed [DATA_WIDTH-1:0] y;
    
    // Overflow flags
    wire overflow_s1, overflow_s2, overflow_s3, overflow_any;
    reg [3:0] overflow_sticky;  // Sticky overflow flags (clear on read)

    //=========================================================================
    // IIR Filter Instance
    //=========================================================================
    iir_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) iir_inst (
        .clk(wb_clk_i),
        .rst_n(~wb_rst_i),
        .x(x_reg),
        .b0_s1(b0_s1), .b1_s1(b1_s1), .b2_s1(b2_s1), .a1_s1(a1_s1), .a2_s1(a2_s1),
        .b0_s2(b0_s2), .b1_s2(b1_s2), .b2_s2(b2_s2), .a1_s2(a1_s2), .a2_s2(a2_s2),
        .b0_s3(b0_s3), .b1_s3(b1_s3), .b2_s3(b2_s3), .a1_s3(a1_s3), .a2_s3(a2_s3),
        .y(y),
        .overflow_s1(overflow_s1),
        .overflow_s2(overflow_s2),
        .overflow_s3(overflow_s3),
        .overflow_any(overflow_any)
    );

    //=========================================================================
    // Wishbone Logic
    //=========================================================================
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_ack_o <= 0;
            wb_dat_o <= 0;
            x_reg <= 0;
            overflow_sticky <= 0;
            
            // Default filter coefficients (Butterworth LP, fc~0.01*fs)
            b0_s1 <= 32'sd5509;    b1_s1 <= 32'sd11019;   b2_s1 <= 32'sd5509;
            a1_s1 <= -32'sd1998080; a2_s1 <= 32'sd971584;
            
            b0_s2 <= 32'sd5180;    b1_s2 <= 32'sd10360;   b2_s2 <= 32'sd5180;
            a1_s2 <= -32'sd1878592; a2_s2 <= 32'sd850752;
            
            b0_s3 <= 32'sd5007;    b1_s3 <= 32'sd10014;   b2_s3 <= 32'sd5007;
            a1_s3 <= -32'sd1815872; a2_s3 <= 32'sd787328;
            
        end else begin
            // Update sticky overflow flags
            if (overflow_s1) overflow_sticky[0] <= 1;
            if (overflow_s2) overflow_sticky[1] <= 1;
            if (overflow_s3) overflow_sticky[2] <= 1;
            if (overflow_any) overflow_sticky[3] <= 1;
            
            // Wishbone transaction
            wb_ack_o <= 0;
            
            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1;
                
                if (wb_we_i) begin
                    // Write transaction
                    case (wb_adr_i)
                        ADDR_X:      x_reg <= wb_dat_i;
                        ADDR_STATUS: overflow_sticky <= 0;  // Clear on write
                        // Section 1
                        ADDR_B0_S1:  b0_s1 <= wb_dat_i;
                        ADDR_B1_S1:  b1_s1 <= wb_dat_i;
                        ADDR_B2_S1:  b2_s1 <= wb_dat_i;
                        ADDR_A1_S1:  a1_s1 <= wb_dat_i;
                        ADDR_A2_S1:  a2_s1 <= wb_dat_i;
                        // Section 2
                        ADDR_B0_S2:  b0_s2 <= wb_dat_i;
                        ADDR_B1_S2:  b1_s2 <= wb_dat_i;
                        ADDR_B2_S2:  b2_s2 <= wb_dat_i;
                        ADDR_A1_S2:  a1_s2 <= wb_dat_i;
                        ADDR_A2_S2:  a2_s2 <= wb_dat_i;
                        // Section 3
                        ADDR_B0_S3:  b0_s3 <= wb_dat_i;
                        ADDR_B1_S3:  b1_s3 <= wb_dat_i;
                        ADDR_B2_S3:  b2_s3 <= wb_dat_i;
                        ADDR_A1_S3:  a1_s3 <= wb_dat_i;
                        ADDR_A2_S3:  a2_s3 <= wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    // Read transaction
                    case (wb_adr_i)
                        ADDR_X:      wb_dat_o <= x_reg;
                        ADDR_Y:      wb_dat_o <= y;
                        ADDR_STATUS: begin
                            wb_dat_o <= {28'd0, overflow_sticky};
                            overflow_sticky <= 0;  // Clear on read
                        end
                        // Section 1
                        ADDR_B0_S1:  wb_dat_o <= b0_s1;
                        ADDR_B1_S1:  wb_dat_o <= b1_s1;
                        ADDR_B2_S1:  wb_dat_o <= b2_s1;
                        ADDR_A1_S1:  wb_dat_o <= a1_s1;
                        ADDR_A2_S1:  wb_dat_o <= a2_s1;
                        // Section 2
                        ADDR_B0_S2:  wb_dat_o <= b0_s2;
                        ADDR_B1_S2:  wb_dat_o <= b1_s2;
                        ADDR_B2_S2:  wb_dat_o <= b2_s2;
                        ADDR_A1_S2:  wb_dat_o <= a1_s2;
                        ADDR_A2_S2:  wb_dat_o <= a2_s2;
                        // Section 3
                        ADDR_B0_S3:  wb_dat_o <= b0_s3;
                        ADDR_B1_S3:  wb_dat_o <= b1_s3;
                        ADDR_B2_S3:  wb_dat_o <= b2_s3;
                        ADDR_A1_S3:  wb_dat_o <= a1_s3;
                        ADDR_A2_S3:  wb_dat_o <= a2_s3;
                        default:     wb_dat_o <= 32'd0;
                    endcase
                end
            end
        end
    end

endmodule
