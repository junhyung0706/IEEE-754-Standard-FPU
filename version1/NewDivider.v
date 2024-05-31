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
    wire [23:0] mantA = (expA == 0) ? {1'b0, A[22:0]} : {1'b1, A[22:0]};
    wire [23:0] mantB = (expB == 0) ? {1'b0, B[22:0]} : {1'b1, B[22:0]};

    // 부호 연산
    wire resultSign = signA ^ signB;

    // 지수 연산
    wire [8:0] expDiff = expA - expB + 8'd127;

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

    // 정상화
    reg [22:0] mantissa;
    reg [8:0] exponent;
    always @(*) begin
        if (quotient[47]) begin
            mantissa = quotient[46:24];
            exponent = expDiff + 1;
        end else begin
            mantissa = quotient[45:23];
            exponent = expDiff;
        end
    end

    // 오버플로우 및 언더플로우 처리
    always @(*) begin
        if (B == 32'b0) begin
            // 나누는 수가 0인 경우
            errorDiv = 1;
            overflowDiv = 0;
            resultDiv = 32'hFFC00000; // NaN
        end else if (A == 32'b0) begin
            // 나누어지는 수가 0인 경우
            errorDiv = 0;
            overflowDiv = 0;
            resultDiv = 32'b0; // 결과도 0
        end else if (exponent >= 8'hFF) begin
            overflowDiv = 1;
            errorDiv = 0;
            resultDiv = {resultSign, 8'hFF, 23'b0}; // 무한대
        end else if (exponent <= 0) begin
            overflowDiv = 0;
            errorDiv = 1;
            resultDiv = 32'b0; // 언더플로우
        end else begin
            overflowDiv = 0;
            errorDiv = 0;
            resultDiv = {resultSign, exponent[7:0], mantissa};
        end
    end

endmodule
