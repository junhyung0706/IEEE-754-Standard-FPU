module Multiplier (
    input clk,
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorMul,
    output reg overflowMul,
    output reg [31:0] resultMul
);

    // Stage 1: Decode input signals and perform mantissa multiplication
    wire signA = A[31];
    wire signB = B[31];
    wire [7:0] expA = A[30:23];
    wire [7:0] expB = B[30:23];
    wire [23:0] mantA = (expA == 0) ? 24'b0 : {1'b1, A[22:0]}; // Regard denormalized number as 0
    wire [23:0] mantB = (expB == 0) ? 24'b0 : {1'b1, B[22:0]};
    wire resultSign = signA ^ signB;
    wire [8:0] expSum = (expA && expB) ? expA + expB : 0; // temporary exp sum, 0 if any input is zero

    reg [47:0] mantMul_stage2;
    reg [8:0] expSum_stage2;
    reg resultSign_stage2;

    integer i;
    always @ (posedge clk) begin
        mantMul_stage2 <= 48'b0;
        for (i = 0; i < 24; i = i + 1) begin
            if (mantB[i])
                mantMul_stage2 <= mantMul_stage2 + (mantA << i);
        end
        expSum_stage2 <= expSum;
        resultSign_stage2 <= resultSign;
    end

    // Stage 2: Normalize the multiplication result
    reg [22:0] mantissa_stage3;
    reg [8:0] exponent_stage3;
    always @ (posedge clk) begin
        if (mantMul_stage2[47]) begin
            mantissa_stage3 <= mantMul_stage2[46:24];
            if(expSum_stage2 >= 127) begin // Underflow Check
                exponent_stage3 <= expSum_stage2 - 126;
            end else begin
                exponent_stage3 <= 0;
            end
        end else begin
            mantissa_stage3 <= mantMul_stage2[45:23];
            if(expSum_stage2 >= 128) begin // Underflow Check
                exponent_stage3 <= expSum_stage2 - 127;
            end else begin
                exponent_stage3 <= 0;
            end
        end
    end

    // Stage 3: Handle exceptions and generate the final result
    always @ (posedge clk) begin
        if ((expA == 8'hff) || (expB == 8'hff)) begin // Check for NaN or Infinity in inputs
            if ((expA == 8'hff && mantA[22:0] != 0) || (expB == 8'hff && mantB[22:0] != 0)) begin
                resultMul <= (mantA[22:0] != 0) ? A : B; // Propagate NaN if either input is NaN
                errorMul <= 1;
                overflowMul <= 0;
            end else if (expA == 8'hff && B[30:23] == 0 || expB == 8'hff && A[30:23] == 0) begin
                resultMul <= {1'b0, 8'hff, 23'h400000}; // Propagate NaN if input is 0 * Infinity
                errorMul <= 1;
                overflowMul <= 0;
            end else begin
                resultMul <= {resultSign_stage2, 8'hff, 23'h0}; // Propagate Infinity if input is nonzero * Infinity
                errorMul <= 0;
                overflowMul <= 1;
            end
        end else if (exponent_stage3 >= 8'hFF) begin
            resultMul <= {resultSign_stage2, 8'hFF, 23'b0}; // Overflow
            overflowMul <= 1;
            errorMul <= 0;
        end else if (exponent_stage3 == 0) begin
            resultMul <= {resultSign_stage2, 31'b0}; // Underflow
            overflowMul <= 0;
            errorMul <= 0;
        end else begin
            resultMul <= {resultSign_stage2, exponent_stage3[7:0], mantissa_stage3};
            overflowMul <= 0;
            errorMul <= 0;
        end
    end

endmodule