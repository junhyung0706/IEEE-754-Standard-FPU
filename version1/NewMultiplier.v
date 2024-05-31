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
    wire [23:0] mantA = (expA == 0) ? {1'b0, A[22:0]} : {1'b1, A[22:0]};
    wire [23:0] mantB = (expB == 0) ? {1'b0, B[22:0]} : {1'b1, B[22:0]};

    // 부호 연산
    wire resultSign = signA ^ signB;

    // 지수 연산
    wire [8:0] expSum = expA + expB - 8'd127;

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

    // 정상화
    reg [22:0] mantissa;
    reg [8:0] exponent;
    always @(*) begin
        if (mantMul[47]) begin
            mantissa = mantMul[46:24];
            exponent = expSum + 1;
        end else begin
            mantissa = mantMul[45:23];
            exponent = expSum;
        end
    end

    // 오버플로우 및 언더플로우 처리
    always @(*) begin
        if ((A == 32'b0) || (B == 32'b0)) begin
            // 입력 중 하나가 0인 경우
            errorMul = 0;
            overflowMul = 0;
            resultMul = 32'b0; // 결과도 0
        end else if (exponent >= 8'hFF) begin
            overflowMul = 1;
            errorMul = 0;
            resultMul = {resultSign, 8'hFF, 23'b0}; // 무한대
        end else if (exponent <= 0) begin
            overflowMul = 0;
            errorMul = 1;
            resultMul = 32'b0; // 언더플로우
        end else begin
            overflowMul = 0;
            errorMul = 0;
            resultMul = {resultSign, exponent[7:0], mantissa};
        end
    end

endmodule
