module Multiplier (
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorMul,
    output reg overflowMul,
    output reg [31:0] resultMul
);
    reg S1, S2, S_result;
    reg [7:0] E1, E2, E_result;
    reg [22:0] F1, F2;
    reg [23:0] M1, M2;
    reg [47:0] M_mul;
    reg [23:0] M_mul_24bit;
    integer shift;

    always @ (*) begin
        // Decode input signals
        S1 = A[31];
        S2 = B[31];
        E1 = A[30:23];
        E2 = B[30:23];
        F1 = A[22:0];
        F2 = B[22:0];

        S_result = S1 ^ S2;

        // 예외처리
        if ((E1 == 8'b1111_1111) || (E2 == 8'b1111_1111)) begin // 입력에서 NaN 혹은 무한대 발생 시
            if (E1 == 8'b1111_1111 && F1 != 0) begin    // A가 NaN인 경우, A의 NaN 값을 전파
                resultMul = A;
                errorMul = 1;
                overflowMul = 0;
            end else if (E2 == 8'b1111_1111 && F2 != 0) begin   // B가 NaN인 경우, B의 NaN 값을 전파
                resultMul = B;
                errorMul = 1;
                overflowMul = 0;
            end else if (E1 == 8'b1111_1111) begin  // A만 무한대인 경우, A의 무한대 값을 전파
                resultMul = A;
                errorMul = 0;
                overflowMul = 1;
            end else if (E2 == 8'b1111_1111) begin  // B만 무한대인 경우, B의 무한대 값을 전파
                resultMul = B;
                errorMul = 0;
                overflowMul = 1;
            end else if (E1 == 8'b1111_1111 && E2 == 8'b0000_0000 && F2 == 23'b0000_0000_0000_0000_0000_000) begin // A와 B가 무한대일 때 B와 A가 0
                resultMul = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000};
                errorMul = 1;
                overflowMul = 0;
            end
        end else begin
            // 정규 수 계산: 묵시적인 선행 1을 가진 가수 계산
            M1 = {1'b1, F1};
            M2 = {1'b1, F2};


            // 지수부를 더해준다
            E_result = E1 + E2;

            // 만티사의 곱셈
            M_mul = M1 * M2;

            // 정규화 및 반올림 처리
            if (M_mul[47]) begin
                M_mul = M_mul >> 1;
                E_result = E_result + 1;
            end

            M_mul_24bit = M_mul[47:24];

            // 반올림 모드 기반 반올림 로직
            case (round_mode)
                2'b00: if (S_result == 0 && M_mul_24bit[0]) M_mul_24bit = M_mul_24bit + 1;
                2'b01: if (S_result == 1 && M_mul_24bit[0]) M_mul_24bit = M_mul_24bit + 1;
                2'b10: if (M_mul_24bit[0] && (M_mul_24bit[1] || |M_mul_24bit[22:1])) M_mul_24bit = M_mul_24bit + 1;
                2'b11: if (M_mul_24bit[0]) M_mul_24bit = M_mul_24bit + 1;
            endcase

            // 최종정규화
            if (M_mul_24bit[23]) begin
                M_mul_24bit = M_mul_24bit >> 1;
                E_result = E_result + 1;
            end

            // 최종 오버플로 및 오류 처리
            if (E_result >= 255) begin
                resultMul = {S_result, 8'hFF, 23'h0}; // Set to max value on overflow
                overflowMul = 1;
                errorMul = 1;
            end else begin
                resultMul = {S_result, E_result[7:0], M_mul_24bit[22:0]};
                overflowMul = 0;
                errorMul = 0;
            end
        end
    end
endmodule
