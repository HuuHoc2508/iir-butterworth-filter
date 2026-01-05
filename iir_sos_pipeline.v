module iir_sos_pipeline #(
    parameter DATA_WIDTH = 32,
    parameter COEFF_WIDTH = 32,
    parameter INTERNAL_WIDTH = 64,
    parameter SCALE_SHIFT = 20
)(
    input wire clk,
    input wire rst_n,
    input wire signed [DATA_WIDTH-1:0] x,
    input wire signed [COEFF_WIDTH-1:0] b0, b1, b2, a1, a2,
    output reg signed [DATA_WIDTH-1:0] y
);

    // Pipeline registers
    reg signed [INTERNAL_WIDTH-1:0] z1_a, z2_a, z1_b, z2_b;
    reg signed [INTERNAL_WIDTH-1:0] mult_b0, mult_b1, mult_b2;
    reg signed [INTERNAL_WIDTH-1:0] mult_a1, mult_a2;
    reg signed [INTERNAL_WIDTH-1:0] b_sum;
    reg signed [INTERNAL_WIDTH-1:0] y_internal;

    // ===== Stage 1: Feedforward Multiply =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_b0 <= 0;
            mult_b1 <= 0;
            mult_b2 <= 0;
        end else begin
            mult_b0 <= x     * b0;
            mult_b1 <= z1_b  * b1;
            mult_b2 <= z2_b  * b2;
        end
    end

    // ===== Stage 2: Feedforward Sum + Feedback Multiply =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_sum    <= 0;
            mult_a1  <= 0;
            mult_a2  <= 0;
        end else begin
            b_sum    <= mult_b0 + mult_b1 + mult_b2;
            mult_a1  <= z1_a * a1;
            mult_a2  <= z2_a * a2;
        end
    end

    // ===== Stage 3: Feedback Sub + Scale + Output =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_internal <= 0;
            y <= 0;
        end else begin
            y_internal <= b_sum - mult_a1 - mult_a2;
            y <= y_internal >>> SCALE_SHIFT;
        end
    end

    // ===== Register Updates (delay matching) =====
    // Use registered y output for feedback (y is already registered in stage 3)
    wire signed [DATA_WIDTH-1:0] z1_b_next = x;
    wire signed [DATA_WIDTH-1:0] z2_b_next = z1_b[DATA_WIDTH-1:0];
    wire signed [DATA_WIDTH-1:0] z1_a_next = y;  // y is registered output
    wire signed [DATA_WIDTH-1:0] z2_a_next = z1_a[DATA_WIDTH-1:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z1_a <= 0; z2_a <= 0;
            z1_b <= 0; z2_b <= 0;
        end else begin
            z1_a <= {{(INTERNAL_WIDTH-DATA_WIDTH){z1_a_next[DATA_WIDTH-1]}}, z1_a_next};
            z2_a <= {{(INTERNAL_WIDTH-DATA_WIDTH){z2_a_next[DATA_WIDTH-1]}}, z2_a_next};
            z1_b <= {{(INTERNAL_WIDTH-DATA_WIDTH){z1_b_next[DATA_WIDTH-1]}}, z1_b_next};
            z2_b <= {{(INTERNAL_WIDTH-DATA_WIDTH){z2_b_next[DATA_WIDTH-1]}}, z2_b_next};
        end
    end

endmodule
