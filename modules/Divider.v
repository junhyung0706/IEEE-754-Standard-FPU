module Divider (
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorDiv,
    output reg overflowDiv,
    output reg [31:0] resultDiv
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
    wire [8:0] expDiff = (expA && expB) ? 8'd255 + expA - expB : 0; // temporary exp diff, 0 if any input is zero

    // 뉴턴-랩슨 방식 초기값 설정
    reg [31:0] x0;
    always @(*) begin
        if (mantB[22:0] == 0)
            x0 = 32'b01111111100000000000000000000000; // 1.0 초기값
        else
            x0 = {8'b01111111, mantB[22:0]};
    end

    // 뉴턴-랩슨 반복
    reg [31:0] x1, x2, x3;
    reg [31:0] temp1, temp2, temp3;
    always @(*) begin
        // 첫 번째 반복
        temp1 = 32'h7FFFFFFF - ((x0 * mantB) >> 23);
        x1 = (x0 * temp1) >> 23;

        // 두 번째 반복
        temp2 = 32'h7FFFFFFF - ((x1 * mantB) >> 23);
        x2 = (x1 * temp2) >> 23;

        // 세 번째 반복
        temp3 = 32'h7FFFFFFF - ((x2 * mantB) >> 23);
        x3 = (x2 * temp3) >> 23;
    end

    // 나눗셈 결과
    wire [47:0] quotient = (mantA * x3) >> 23;

    // 정상화 및 반올림 처리
    reg [22:0] mantissa;
    reg [8:0] exponent;
    reg round_bit;
    always @(*) begin
        if (quotient[47]) begin
            mantissa = quotient[46:24];
            round_bit = quotient[23]; // 마지막 비트
            if(expDiff >= 127) begin // Underflow Check
                exponent = expDiff - 127;
            end else begin
                exponent = 0;
            end
        end else begin
            mantissa = quotient[45:23];
            round_bit = quotient[22]; // 마지막 비트
            if(expDiff >= 128) begin // Underflow Check
                exponent = expDiff - 128;
            end else begin
                exponent = 0;
            end
        end

        // Rounding logic based on rounding mode
        case (round_mode)
            2'b00: if (round_bit) mantissa = mantissa + 1;
            2'b01: if (round_bit && resultSign) mantissa = mantissa + 1;
            2'b10: if (round_bit && (mantissa[0] || |quotient[22:1])) mantissa = mantissa + 1;
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
                resultDiv = (mantA[22:0] != 0) ? A : B; // Propagate NaN if either input is NaN
                errorDiv = 1;
                overflowDiv = 0;
            end else if (expA == 8'hff && expB == 8'hff) begin
                resultDiv = {1'b0, 8'hff, 23'h400000}; // Set to NaN if both inputs are Infinities
                errorDiv = 1;
                overflowDiv = 0;
            end else if (expA == 8'hff) begin
                resultDiv = {resultSign, 8'hff, 23'h0}; // Proagate Infinity if input is Infinity / nonzero
                errorDiv = 0;
                overflowDiv = 1;
            end else begin
                resultDiv = {resultSign, 31'b0}; // Set to 0 if input is nonzero / Infinity
                errorDiv = 0;
                overflowDiv = 0;
            end
        end else if(A[30:23] == 0 && B[30:23] == 0) begin
            resultDiv = {1'b0, 8'hff, 23'h400000}; // Set to NaN if both inputs are 0
            errorDiv = 1;
            overflowDiv = 0;
        end else if (B[30:23] == 0) begin
            resultDiv = {resultSign, 8'hff, 23'h0}; // Set to Infinity if input is nonzero / 0
            errorDiv = 0;
            overflowDiv = 1;
        end else if (exponent >= 8'hFF) begin
            resultDiv = {resultSign, 8'hFF, 23'b0}; // Overflow
            overflowDiv = 1;
            errorDiv = 0;
        end else if (exponent == 0) begin
            resultDiv = {resultSign, 31'b0}; // Underflow
            overflowDiv = 0;
            errorDiv = 0;
        end else begin
            resultDiv = {resultSign, exponent[7:0], mantissa};
            overflowDiv = 0;
            errorDiv = 0;
        end
    end

endmodule
