module Divider_Pipeline(
    input clk,
    input [31:0] A, B,
    output reg [31:0] result,
    output reg overflow,
    output reg underflow
);

    // 스테이지 레지스터 선언
    reg sign_A, sign_B, sign_result;
    reg [7:0] exp_A, exp_B, exp_diff, exp_result;
    reg [23:0] man_A, man_B, man_result;
    reg [47:0] man_quotient;
    reg [31:0] Y0, Y1, Y2; // 뉴턴-랩슨 반복 계산을 위한 근사값

    always @(posedge clk) begin
        // Stage 1: 부호 비트 처리 및 지수 차이 계산
        sign_A <= A[31];
        sign_B <= B[31];
        exp_A <= A[30:23];
        exp_B <= B[30:23];
        man_A <= {1'b1, A[22:0]};
        man_B <= {1'b1, B[22:0]};
        sign_result <= sign_A ^ sign_B;
        exp_diff <= exp_A - exp_B + 8'd127; // 지수의 차이 계산

        // Stage 2: 초기 근사값 Y0 계산
        if (B[30:23] == 8'h0) begin
            // B가 0인 경우 예외 처리 (나눗셈 불가)
            Y0 <= 32'h7FFFFFFF; // 최대값으로 설정
        end else begin
            // 초기 근사값 Y0 설정 (기본적으로 역수의 초기 근사값으로 설정)
            Y0 <= 32'h4C000000 - (B[30:23] << 23);
        end

        // Stage 3: 첫 번째 반복 계산
        Y1 <= Y0 * (48'h100000000 - (man_B * Y0) >> 24);

        // Stage 4: 두 번째 반복 계산
        Y2 <= Y1 * (48'h100000000 - (man_B * Y1) >> 24);

        // Stage 5: 최종 근사값 계산 및 곱셈
        man_quotient <= man_A * Y2;

        // Stage 6: 정규화 및 결과 조합
        if (man_quotient[47]) begin
            man_result <= man_quotient[46:24];
            exp_result <= exp_diff + 1;
        end else begin
            man_result <= man_quotient[45:23];
            exp_result <= exp_diff;
        end

        // Overflow 및 Underflow 체크
        overflow <= (exp_result >= 8'hFF);
        underflow <= (exp_result <= 8'h00);

        // 결과 출력
        if (overflow) begin
            result <= {sign_result, 8'hFF, 23'h0}; // Infinity
        end else if (underflow) begin
            result <= {sign_result, 8'h00, 23'h0}; // Zero
        end else begin
            result <= {sign_result, exp_result[7:0], man_result[22:0]};
        end
    end
endmodule
