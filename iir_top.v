module iir_top #(
    parameter DATA_WIDTH = 32,
    parameter COEFF_WIDTH = 32,
    parameter INTERNAL_WIDTH = 64,
    parameter SCALE_SHIFT = 20
) (
    input wire clk,
    input wire rst_n,
    input wire signed [DATA_WIDTH-1:0] x,
    input wire signed [COEFF_WIDTH-1:0] b0_s1, b1_s1, b2_s1, a1_s1, a2_s1,
    input wire signed [COEFF_WIDTH-1:0] b0_s2, b1_s2, b2_s2, a1_s2, a2_s2,
    input wire signed [COEFF_WIDTH-1:0] b0_s3, b1_s3, b2_s3, a1_s3, a2_s3,
    output wire signed [DATA_WIDTH-1:0] y
);
    wire signed [DATA_WIDTH-1:0] s1_s2, s2_s3;

    // Section 1
    iir_sos #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) sos1 (
        .clk(clk),
        .rst_n(rst_n),
        .x(x),
        .b0(b0_s1),
        .b1(b1_s1),
        .b2(b2_s1),
        .a1(a1_s1),
        .a2(a2_s1),
        .y(s1_s2)
    );

    // Section 2
    iir_sos #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) sos2 (
        .clk(clk),
        .rst_n(rst_n),
        .x(s1_s2),
        .b0(b0_s2),
        .b1(b1_s2),
        .b2(b2_s2),
        .a1(a1_s2),
        .a2(a2_s2),
        .y(s2_s3)
    );

    // Section 3
    iir_sos #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) sos3 (
        .clk(clk),
        .rst_n(rst_n),
        .x(s2_s3),
        .b0(b0_s3),
        .b1(b1_s3),
        .b2(b2_s3),
        .a1(a1_s3),
        .a2(a2_s3),
        .y(y)
    );
endmodule