module Adder(
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorAdd,
    output reg overflowAdd,
    output reg [31:0] resultAdd
);

    reg S1, S2, S_result;
    reg [7:0] E1, E2, E_result;
    reg [22:0] F1, F2;
    reg [23:0] M1, M2;
    reg [24:0] M_sum; // 25비트 mantissa result (includes overflow handling)
    reg carry; // carry from the addition
    integer shift;

    always @ (*) begin
        // Decode input signals
        S1 = A[31];
        S2 = B[31];
        E1 = A[30:23];
        E2 = B[30:23];
        F1 = A[22:0];
        F2 = B[22:0];

        // 예외처리
        if ((E1 == 8'b1111_1111) || (E2 == 8'b1111_1111)) begin // 입력에서 NaN 혹은 무한대 발생 시
            if (E1 == 8'b1111_1111 && F1 != 0) begin    // A가 NaN인 경우, A의 NaN 값을 전파
                resultAdd = A;
                errorAdd = 1;
                overflowAdd = 0;
            end else if (E2 == 8'b1111_1111 && F2 != 0) begin   // B가 NaN인 경우, B의 NaN 값을 전파
                resultAdd = B;
                errorAdd = 1;
                overflowAdd = 0;
            end else if (E1 == 8'b1111_1111 && E2 == 8'b1111_1111) begin // A와 B 모두 무한대일 때
                if (S1 != S2) begin // 부호가 서로 다를 경우, 결과는 NaN
                    resultAdd = {1'b0, 8'b1111_1111, 23'h400000}; // 표준 NaN 출력
                    errorAdd = 1;
                    overflowAdd = 0;
                end else begin  // 부호가 같을 경우, 같은 부호의 무한대를 전파
                    resultAdd = A; // 같은 부호의 무한대 전파
                    errorAdd = 0;
                    overflowAdd = 0;
                end
            end else if (E1 == 8'b1111_1111) begin  // A만 무한대인 경우, A의 무한대 값을 전파
                resultAdd = A;
                errorAdd = 0;
                overflowAdd = 0;
            end else begin  // B만 무한대인 경우, B의 무한대 값을 전파
                resultAdd = B;
                errorAdd = 0;
                overflowAdd = 0;
            end
        end else begin
            // 정규 수 계산: 묵시적인 선행 1을 가진 가수 계산
            M1 = {1'b1, F1};
            M2 = {1'b1, F2};


            // 지수차를 기준으로 만티사 정렬
            if (E1 > E2) begin
                shift = E1 - E2;
                M2 = M2 >> shift;
                E_result = E1;
            end else begin
                shift = E2 - E1;
                M1 = M1 >> shift;
                E_result = E2;
            end

            // 만티사의 더하고 빼기
            if (S1 == S2) begin
                {carry, M_sum} = M1 + M2;
                S_result = S1;
            end else begin
                if (M1 >= M2) begin
                    M_sum = M1 - M2;
                    S_result = S1;
                end else begin
                    M_sum = M2 - M1;
                    S_result = S2;
                end
            end

            // 정규화 및 반올림 처리
            if (M_sum[24]) begin
                M_sum = M_sum >> 1;
                E_result = E_result + 1;
            end

            // 반올림 모드 기반 반올림 로직
            case (round_mode)
                2'b00: if (S_result == 0 && M_sum[0]) M_sum = M_sum + 1;
                2'b01: if (S_result == 1 && M_sum[0]) M_sum = M_sum + 1;
                2'b10: if (M_sum[0] && (M_sum[1] || |M_sum[22:1])) M_sum = M_sum + 1;
                2'b11: if (M_sum[0]) M_sum = M_sum + 1;
            endcase

            // 최종정규화
            if (M_sum[24]) begin
                M_sum = M_sum >> 1;
                E_result = E_result + 1;
            end

            // 최종 오버플로 및 오류 처리
            if (E_result >= 255) begin
                resultAdd = {S_result, 8'hFF, 23'h0}; // Set to max value on overflow
                overflowAdd = 1;
                errorAdd = 1;
            end else begin
                resultAdd = {S_result, E_result[7:0], M_sum[22:0]};
                overflowAdd = 0;
                errorAdd = 0;
            end
        end
    end
endmodule
