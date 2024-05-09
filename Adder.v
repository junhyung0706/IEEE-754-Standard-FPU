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
    reg [24:0] M_sum; // 가수합 결과를 위한 레지스터 (overflow를 위해 하나 더 추가)
    reg carry; // 덧셈에서의 캐리 비트
    integer shift;

    always @(*) begin
        begin
            S1 = A[31];
            S2 = B[31];
            E1 = A[30:23];
            E2 = B[30:23];
            F1 = A[22:0];
            F2 = B[22:0];
            M1 = {1'b1, F1}; // Implicit leading one
            M2 = {1'b1, F2}; // Implicit leading one

            // 지수 차이 조정
            if (E1 > E2) begin
                shift = E1 - E2;
                M2 = M2 >> shift;
                E_result = E1;
            end else begin
                shift = E2 - E1;
                M1 = M1 >> shift;
                E_result = E2;
            end
        end

        // 가수 덧셈
        begin
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
        end

        // 정규화 및 라운딩 로직
        begin
            if (M_sum[24]) begin
                M_sum = M_sum >> 1;
                E_result = E_result + 1;
            end

            // 라운딩 처리
            case (round_mode)
                2'b00: begin // Round towards zero
                    // No additional rounding needed, truncation already done
                end
                2'b01: begin // Round towards nearest even
                    if (M_sum[0] && (M_sum[1] || |M_sum[22:1])) begin
                        M_sum = M_sum + 1;
                    end
                end
                2'b10: begin // Round towards +∞
                    if (S_result == 0 && M_sum[0]) begin
                        M_sum = M_sum + 1;
                    end
                end
                2'b11: begin // Round towards -∞
                    if (S_result == 1 && M_sum[0]) begin
                        M_sum = M_sum + 1;
                    end
                end
            endcase

            if (M_sum[24]) begin
                M_sum = M_sum >> 1;
                E_result = E_result + 1;
            end
        end

        // 오버플로우 체크
        begin
            if (E_result >= 255) begin
                overflowAdd = 1;
                errorAdd = 1;
            end else begin
                overflowAdd = 0;
                errorAdd = 0;
                resultAdd = {S_result, E_result[7:0], M_sum[22:0]};
            end
        end
    end

endmodule
