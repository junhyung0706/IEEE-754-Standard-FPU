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
    reg [24:0] M_mul_25bit;
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

        // Exception handling
        //A가 무한, B는 0일 때 출력은 NaN
        if (E1 == 8'b1111_1111 && F1 == 23'b000_0000_0000_0000_0000_0000 && E2 == 8'b0000_0000 && F2 == 23'b000_0000_0000_0000_0000_0000) begin
            resultMul = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000};
            overflowMul = 0;
            errorMul = 1;
        end
        //A가 0, B는 무한일 때 출력은 NaN
        else if (E1 == 8'b0000_0000 && F1 == 23'b000_0000_0000_0000_0000_0000 && E2 == 8'b1111_1111 && F2 == 23'b000_0000_0000_0000_0000_0000) begin
            resultMul = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000};
            overflowMul = 0;
            errorMul = 1;
        end else begin
            // Normal multiplication process
            M1 = {1'b1, F1};  // Include the implicit leading one
            M2 = {1'b1, F2};

            // Multiply mantissas
            M_mul = M1 * M2; // 48비트 곱셈 결과

            // Calculate new exponent
            E_result = E1 + E2 - 127 + 1;  // Adjust the exponent for bias

            // Normalize the product
            shift = 0;
            while (M_mul[47] == 0 && shift < 24) begin
                M_mul = M_mul << 1;
                shift = shift + 1;
            end
            E_result = E_result - shift;

            // Extract the upper 24 bits as the result mantissa
            M_mul_25bit = {1'b0, M_mul[47:24]}; //최상위 비트는 오버플로우 검출용, 최하위비트는 반올림용

            // 라운딩 처리
            case (round_mode)
                2'b00: begin // Round towards +∞
                    if (S_result == 0 && M_mul_25bit[0] == 1) begin
                        M_mul_25bit = M_mul_25bit + 1;
                    end
                end
                2'b01: begin // Round towards -∞
                    if (S_result == 1 && M_mul_25bit[0] == 1) begin
                        M_mul_25bit = M_mul_25bit + 1;
                    end
                end
                2'b10: begin // Round towards nearest even
                    if (M_mul_25bit[1:0] == 2'b11) begin
                        M_mul_25bit = M_mul_25bit + 1;
                    end
                end
                2'b11: begin // Rounding ties away from zero
                    if (S_result == 0 && M_mul_25bit[0] == 1) begin
                        M_mul_25bit = M_mul_25bit + 1;
                    end
                    else if (S_result == 1 && M_mul_25bit[0] == 1) begin
                        M_mul_25bit = M_mul_25bit + 1;
                    end
                end
            endcase

            // Check for overflow due to rounding
            if (M_mul_25bit[24]) begin
                M_mul_25bit = M_mul_25bit >> 1;
                E_result = E_result + 1;
            end

            // Final check for overflow and underflow
            if (E_result >= 255) begin
                resultMul = {S_result, 8'hFF, 23'h0}; // Overflow, set to infinity
                overflowMul = 1;
                errorMul = 1;
            end else if (E_result <= 0) begin
                resultMul = {S_result, 8'h00, 23'h0}; // Underflow, set to zero
                overflowMul = 0;
                errorMul = 0;
            end else begin
                resultMul = {S_result, E_result[7:0], M_mul_25bit[23:1]};
                overflowMul = 0;
                errorMul = 0;
            end
        end
    end
endmodule
