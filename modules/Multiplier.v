module Multiplier (
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorMul,
    output reg overflowMul,
    output reg [31:0] resultMul
);

    // IEEE 754 부동 소수점 형식
    wire signA = A[31];
    wire signB = B[31];
    wire [7:0] expA = A[30:23];
    wire [7:0] expB = B[30:23];
    wire [23:0] mantA = (expA == 0) ? 24'b0 : {1'b1, A[22:0]}; // Regard denormalized number as 0
    wire [23:0] mantB = (expB == 0) ? 24'b0 : {1'b1, B[22:0]};

    // 부호 연산
    wire resultSign = signA ^ signB;

    // 지수 연산
    wire [8:0] expSum = (expA && expB) ? expA + expB : 0; // temporary exp sum, 0 if any input is zero

    // 배열 곱셈을 위한 가수부 곱셈
    reg [47:0] mantMul;
    integer i;
    always @(*) begin
        mantMul = 48'b0;
        for (i = 0; i < 24; i = i + 1) begin
            if (mantB[i])
                mantMul = mantMul + (mantA << i);
        end
    end

    // 정상화 및 반올림 처리
    reg [22:0] mantissa;
    reg [8:0] exponent;
    reg round_bit;
    always @(*) begin
        if (mantMul[47]) begin
            mantissa = mantMul[46:24];
            round_bit = mantMul[23]; // 마지막 비트
            if(expSum >= 127) begin // Underflow Check
                exponent = expSum - 126;
            end else begin
                exponent = 0;
            end
        end else begin
            mantissa = mantMul[45:23];
            round_bit = mantMul[22]; // 마지막 비트
            if(expSum >= 128) begin // Underflow Check
                exponent = expSum - 127;
            end else begin
                exponent = 0;
            end
        end

        // Rounding logic based on rounding mode
        case (round_mode)
            2'b00: if (round_bit) mantissa = mantissa + 1;
            2'b01: if (round_bit && resultSign) mantissa = mantissa + 1;
            2'b10: if (round_bit && (mantissa[0] || |mantMul[22:1])) mantissa = mantissa + 1;
            2'b11: if (round_bit) mantissa = mantissa + 1;
        endcase

        // Normalize again if rounding caused an overflow
        if (mantissa[23]) begin
            mantissa = mantissa >> 1;
            exponent = exponent + 1;
        end
    end

    // Exception Handling
    always @(*) begin
        if ((expA == 8'hff) || (expB == 8'hff)) begin // Check for NaN or Infinity in inputs
            if ((expA == 8'hff && mantA[22:0] != 0) || (expB == 8'hff && mantB[22:0] != 0)) begin
                resultMul = (mantA[22:0] != 0) ? A : B; // Propagate NaN if either input is NaN
                errorMul = 1;
                overflowMul = 0;
            end else if (expA == 8'hff && B[30:23] == 0 || expB == 8'hff && A[30:23] == 0) begin
                resultMul = {1'b0, 8'hff, 23'h400000}; // Propagate NaN if input is 0 * Infinity
                errorMul = 1;
                overflowMul = 0;
            end else begin
                resultMul = {resultSign, 8'hff, 23'h0}; // Propagate Infinity if input is nonzero * Infinity
                errorMul = 0;
                overflowMul = 1;
            end
        end else if (exponent >= 8'hFF) begin
            resultMul = {resultSign, 8'hFF, 23'b0}; // Overflow
            overflowMul = 1;
            errorMul = 0;
        end else if (exponent == 0) begin
            resultMul = {resultSign, 31'b0}; // Underflow
            overflowMul = 0;
            errorMul = 0;
        end else begin
            resultMul = {resultSign, exponent[7:0], mantissa};
            overflowMul = 0;
            errorMul = 0;
        end
    end

endmodule
