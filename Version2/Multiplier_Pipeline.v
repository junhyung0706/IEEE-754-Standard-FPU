module Multiplier_Pipeline(
    input clk,
    input [31:0] A, B,
    output reg [31:0] result,
    output reg overflow,
    output reg underflow
);

    // 스테이지 레지스터 선언
    reg sign_A, sign_B, sign_result;
    reg [7:0] exp_A, exp_B, exp_sum, exp_result;
    reg [23:0] man_A, man_B, man_result;
    wire [47:0] man_product;
    reg overflow_stage, underflow_stage;

    // Booth's Algorithm 곱셈기 인스턴스화
    Booth_Multiplier booth_multiplier(.A(man_A), .B(man_B), .product(man_product));

    always @(posedge clk) begin
        // Stage 1: 부호 비트 처리 및 지수 덧셈
        sign_A <= A[31];
        sign_B <= B[31];
        exp_A <= A[30:23];
        exp_B <= B[30:23];
        man_A <= {1'b1, A[22:0]};
        man_B <= {1'b1, B[22:0]};
        sign_result <= sign_A ^ sign_B;
        exp_sum <= exp_A + exp_B - 8'd127;

        // Stage 2: 가수 곱셈 (Booth's Algorithm 사용)
        // man_product는 이미 Booth_Multiplier 모듈에서 계산됩니다.

        // Stage 3: 정규화
        if (man_product[47]) begin
            man_result <= man_product[46:24];
            exp_result <= exp_sum + 1;
        end else if (man_product[46]) begin
            man_result <= man_product[45:23];
            exp_result <= exp_sum;
        end else begin
            man_result <= man_product[44:22];
            exp_result <= exp_sum - 1;
        end

        // Overflow 및 Underflow 체크
        overflow_stage <= (exp_result >= 8'hFF);
        underflow_stage <= (exp_result <= 8'h00);

        // Stage 4: 최종 결과 생성
        if (overflow_stage) begin
            result <= {sign_result, 8'hFF, 23'h0}; // Infinity
            overflow <= 1;
            underflow <= 0;
        end else if (underflow_stage) begin
            result <= {sign_result, 8'h00, 23'h0}; // Zero
            overflow <= 0;
            underflow <= 1;
        end else begin
            result <= {sign_result, exp_result[7:0], man_result[22:0]};
            overflow <= 0;
            underflow <= 0;
        end
    end
endmodule
