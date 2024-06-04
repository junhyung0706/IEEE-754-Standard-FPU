module Divider (
    input clk,
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorDiv,
    output reg overflowDiv,
    output reg [31:0] resultDiv
);

    // Stage 1: Decode input signals and initial setup
    wire signA = A[31];
    wire signB = B[31];
    wire [7:0] expA = A[30:23];
    wire [7:0] expB = B[30:23];
    wire [23:0] mantA = (expA == 0) ? 24'b0 : {1'b1, A[22:0]}; // Regard denormalized number as 0
    wire [23:0] mantB = (expB == 0) ? 24'b0 : {1'b1, B[22:0]};
    wire resultSign = signA ^ signB;
    wire [8:0] expDiff = (expA && expB) ? 8'd255 + expA - expB : 0; // temporary exp diff, 0 if any input is zero

    reg [31:0] x0_stage2;
    reg [23:0] mantB_stage2;
    reg [23:0] mantA_stage2;
    reg resultSign_stage2;
    reg [8:0] expDiff_stage2;

    always @ (posedge clk) begin
        mantB_stage2 <= mantB;
        mantA_stage2 <= mantA;
        resultSign_stage2 <= resultSign;
        expDiff_stage2 <= expDiff;

        if (mantB[22:0] == 0)
            x0_stage2 <= 32'b01111111100000000000000000000000; // 1.0 초기값
        else
            x0_stage2 <= {8'b01111111, mantB[22:0]};
    end

    // Stage 2: Newton-Raphson iteration step 1
    reg [31:0] x1_stage3;
    reg [23:0] mantB_stage3;
    reg [23:0] mantA_stage3;
    reg resultSign_stage3;
    reg [8:0] expDiff_stage3;

    reg [31:0] temp1;
    always @ (posedge clk) begin
        temp1 <= 32'h7FFFFFFF - ((x0_stage2 * mantB_stage2) >> 23);
        x1_stage3 <= (x0_stage2 * temp1) >> 23;

        mantB_stage3 <= mantB_stage2;
        mantA_stage3 <= mantA_stage2;
        resultSign_stage3 <= resultSign_stage2;
        expDiff_stage3 <= expDiff_stage2;
    end

    // Stage 3: Newton-Raphson iteration step 2
    reg [31:0] x2_stage4;
    reg [23:0] mantA_stage4;
    reg resultSign_stage4;
    reg [8:0] expDiff_stage4;

    reg [31:0] temp2;
    always @ (posedge clk) begin
        temp2 <= 32'h7FFFFFFF - ((x1_stage3 * mantB_stage3) >> 23);
        x2_stage4 <= (x1_stage3 * temp2) >> 23;

        mantA_stage4 <= mantA_stage3;
        resultSign_stage4 <= resultSign_stage3;
        expDiff_stage4 <= expDiff_stage3;
    end

    // Stage 4: Handle exceptions and generate the final result
    reg [47:0] quotient;
    reg [22:0] mantissa;
    reg [8:0] exponent;

    always @ (posedge clk) begin
        quotient <= (mantA_stage4 * x2_stage4) >> 23;

        // Normalize the result
        if (quotient[47]) begin
            mantissa <= quotient[46:24];
            if(expDiff_stage4 >= 127) begin // Underflow Check
                exponent <= expDiff_stage4 - 127;
            end else begin
                exponent <= 0;
            end
        end else begin
            mantissa <= quotient[45:23];
            if(expDiff_stage4 >= 128) begin // Underflow Check
                exponent <= expDiff_stage4 - 128;
            end else begin
                exponent <= 0;
            end
        end

        // Exception Handling
        if ((expA == 8'hff) || (expB == 8'hff)) begin // Check for NaN or Infinity in inputs
            if ((expA == 8'hff && mantA[22:0] != 0) || (expB == 8'hff && mantB[22:0] != 0)) begin
                resultDiv <= (mantA[22:0] != 0) ? A : B; // Propagate NaN if either input is NaN
                errorDiv <= 1;
                overflowDiv <= 0;
            end else if (expA == 8'hff && expB == 8'hff) begin
                resultDiv <= {1'b0, 8'hff, 23'h400000}; // Set to NaN if both inputs are Infinities
                errorDiv <= 1;
                overflowDiv <= 0;
            end else if (expA == 8'hff) begin
                resultDiv <= {resultSign_stage4, 8'hff, 23'h0}; // Propagate Infinity if input is Infinity / nonzero
                errorDiv <= 0;
                overflowDiv <= 1;
            end else begin
                resultDiv <= {resultSign_stage4, 31'b0}; // Set to 0 if input is nonzero / Infinity
                errorDiv <= 0;
                overflowDiv <= 0;
            end
        end else if(A[30:23] == 0 && B[30:23] == 0) begin
            resultDiv <= {1'b0, 8'hff, 23'h400000}; // Set to NaN if both inputs are 0
            errorDiv <= 1;
            overflowDiv <= 0;
        end else if (B[30:23] == 0) begin
            resultDiv <= {resultSign_stage4, 8'hff, 23'h0}; // Set to Infinity if input is nonzero / 0
            errorDiv <= 0;
            overflowDiv <= 1;
        end else if (exponent >= 8'hFF) begin
            resultDiv <= {resultSign_stage4, 8'hFF, 23'b0}; // Overflow
            overflowDiv <= 1;
            errorDiv <= 0;
        end else if (exponent == 0) begin
            resultDiv <= {resultSign_stage4, 31'b0}; // Underflow
            overflowDiv <= 0;
            errorDiv <= 0;
        end else begin
            resultDiv <= {resultSign_stage4, exponent[7:0], mantissa};
            overflowDiv <= 0;
            errorDiv <= 0;
        end
    end

endmodule