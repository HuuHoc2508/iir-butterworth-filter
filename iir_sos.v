module iir_sos #(
    parameter DATA_WIDTH = 32,
    parameter COEFF_WIDTH = 32,
    parameter INTERNAL_WIDTH = 64,
    parameter SCALE_SHIFT = 20
) (
    input wire clk,
    input wire rst_n,
    input wire signed [DATA_WIDTH-1:0] x,
    input wire signed [COEFF_WIDTH-1:0] b0, b1, b2, a1, a2,
    output wire signed [DATA_WIDTH-1:0] y
);
    // Internal registers
    reg signed [INTERNAL_WIDTH-1:0] z1_a, z2_a, z1_b, z2_b;
    reg signed [DATA_WIDTH-1:0] y_reg;  // Registered output for feedback
    
    wire signed [INTERNAL_WIDTH-1:0] b_out, a_out;
    wire signed [DATA_WIDTH-1:0] z1_b_next, z2_b_next, z1_a_next, z2_a_next;

    // Feedforward path
    assign z1_b_next = x;
    assign z2_b_next = z1_b[DATA_WIDTH-1:0];
    assign b_out = x * b0 + z1_b * b1 + z2_b * b2;

    // Feedback path - Use REGISTERED y_reg for feedback (not combinational y)
    assign z1_a_next = y_reg;
    assign z2_a_next = z1_a[DATA_WIDTH-1:0];
    assign a_out = b_out - z1_a * a1 - z2_a * a2;

    // Output - connect to registered value
    assign y = y_reg;

    // Register updates - includes output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z1_a <= 0;
            z2_a <= 0;
            z1_b <= 0;
            z2_b <= 0;
            y_reg <= 0;
        end else begin
            // Register the scaled output
            y_reg <= a_out >>> SCALE_SHIFT;
            // Update delay registers
            z1_a <= {{(INTERNAL_WIDTH-DATA_WIDTH){z1_a_next[DATA_WIDTH-1]}}, z1_a_next};
            z2_a <= {{(INTERNAL_WIDTH-DATA_WIDTH){z2_a_next[DATA_WIDTH-1]}}, z2_a_next};
            z1_b <= {{(INTERNAL_WIDTH-DATA_WIDTH){z1_b_next[DATA_WIDTH-1]}}, z1_b_next};
            z2_b <= {{(INTERNAL_WIDTH-DATA_WIDTH){z2_b_next[DATA_WIDTH-1]}}, z2_b_next};
        end
    end
endmodule