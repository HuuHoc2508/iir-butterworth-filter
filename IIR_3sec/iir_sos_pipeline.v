// IIR Second-Order Section with Pipeline, Overflow Detection, and Saturation
// Enhanced version with saturation logic to prevent overflow wrap-around

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
    output reg signed [DATA_WIDTH-1:0] y,
    output reg overflow_flag  // Overflow detection output
);

    // Maximum and minimum values for saturation
    localparam signed [DATA_WIDTH-1:0] MAX_VALUE = {1'b0, {(DATA_WIDTH-1){1'b1}}};  // 2^31-1
    localparam signed [DATA_WIDTH-1:0] MIN_VALUE = {1'b1, {(DATA_WIDTH-1){1'b0}}};  // -2^31

    // Pipeline registers
    reg signed [INTERNAL_WIDTH-1:0] z1_a, z2_a, z1_b, z2_b;
    reg signed [INTERNAL_WIDTH-1:0] mult_b0, mult_b1, mult_b2;
    reg signed [INTERNAL_WIDTH-1:0] mult_a1, mult_a2;
    reg signed [INTERNAL_WIDTH-1:0] b_sum;
    reg signed [INTERNAL_WIDTH-1:0] y_internal;
    
    // Delayed input for pipeline synchronization
    reg signed [DATA_WIDTH-1:0] x_d1, x_d2, x_d3;

    // ===== Stage 1: Feedforward Multiply =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_b0 <= 0;
            mult_b1 <= 0;
            mult_b2 <= 0;
            x_d1 <= 0;
        end else begin
            mult_b0 <= x     * b0;
            mult_b1 <= z1_b  * b1;
            mult_b2 <= z2_b  * b2;
            x_d1 <= x;
        end
    end

    // ===== Stage 2: Feedforward Sum + Feedback Multiply =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_sum    <= 0;
            mult_a1  <= 0;
            mult_a2  <= 0;
            x_d2 <= 0;
        end else begin
            b_sum    <= mult_b0 + mult_b1 + mult_b2;
            mult_a1  <= z1_a * a1;
            mult_a2  <= z2_a * a2;
            x_d2 <= x_d1;
        end
    end

    // ===== Stage 3: Feedback Sub + Scale =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_internal <= 0;
            x_d3 <= 0;
        end else begin
            y_internal <= b_sum - mult_a1 - mult_a2;
            x_d3 <= x_d2;
        end
    end

    // ===== Stage 4: Saturation + Output =====
    wire signed [INTERNAL_WIDTH-1:0] y_scaled = y_internal >>> SCALE_SHIFT;
    wire overflow_positive = (y_scaled > MAX_VALUE);
    wire overflow_negative = (y_scaled < MIN_VALUE);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y <= 0;
            overflow_flag <= 0;
        end else begin
            // Saturation logic
            if (overflow_positive) begin
                y <= MAX_VALUE;
                overflow_flag <= 1;
            end else if (overflow_negative) begin
                y <= MIN_VALUE;
                overflow_flag <= 1;
            end else begin
                y <= y_scaled[DATA_WIDTH-1:0];
                overflow_flag <= 0;
            end
        end
    end

    // ===== Delay Register Updates =====
    // Feedforward delay line (use delayed x for proper timing)
    wire signed [DATA_WIDTH-1:0] z1_b_next = x_d3;
    wire signed [DATA_WIDTH-1:0] z2_b_next = z1_b[DATA_WIDTH-1:0];
    
    // Feedback delay line (use saturated output)
    wire signed [DATA_WIDTH-1:0] z1_a_next = y;  // y is already saturated and registered
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
