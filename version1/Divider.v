module Divider (
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorDiv,
    output reg overflowDiv,
    output reg [31:0] resultDiv
);
    reg S1, S2, S_result;
    reg [7:0] E1, E2, E_result;
    reg [22:0] F1, F2;
    reg [23:0] M1, M2;
    reg [47:0] M1_ext, M2_ext, M_div_ext;
    reg [23:0] M_div;
    reg [24:0] M_Div_25bit;
    integer shift_count;

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
        // 0 / 0은 NaN
        if (E1 == 8'b0000_0000 && F1 == 23'b0000_0000_0000_0000_0000_000 && E2 == 8'b0000_0000 && F2 == 23'b0000_0000_0000_0000_0000_000) begin
            resultDiv = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000}; // NaN
            errorDiv = 1;
            overflowDiv = 0;
        // 무한 / 무한 = NaN
        end else if (E1 == 8'b1111_1111 && E2 == 8'b1111_1111 && F1 == 23'b000_0000_0000_0000_0000_0000 && F2 == 23'b000_0000_0000_0000_0000_0000) begin 
            resultDiv = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000}; // NaN
            errorDiv = 1;
            overflowDiv = 0;
        // 0으로 나누면 무한
        end else if (E2 == 8'b1111_1111 && F2 == 23'b000_0000_0000_0000_0000_0000) begin
            resultDiv = {S_result, 8'b1111_1111, 23'b000_0000_0000_0000_0000_0000};
            errorDiv = 0;
            overflowDiv = 1;
        end else begin
            // Normalized number calculation: calculate mantissas with implicit leading 1
            M1 = {1'b1, F1};
            M2 = {1'b1, F2};

            // Exponent calculation
            E_result = E1 - E2 + 127 - 1;

            // Mantissa division
            M1_ext = M1 << 24; // Convert to extended fixed-point format
            M2_ext = M2;
            M_div_ext = M1_ext / M2_ext;
            M_div = M_div_ext[23:0]; // Truncate to 24 bits
            
            shift_count = 0;
            while (M_div[23] == 0 && shift_count < 24) begin
                M_div = M_div << 1;
                shift_count = shift_count + 1;
            end
            E_result = E_result - shift_count;
            
            M_Div_25bit = {1'b0, M_div}; //최상위 비트는 오버플로우 검출용, 최하위비트는 module Divider
            
            // 라운딩 처리
            case (round_mode)
                2'b00: begin // Round towards +∞
                    if (S_result == 0 && M_Div_25bit == 1) begin
                        M_Div_25bit = M_Div_25bit + 1;
                    end
                end
                2'b01: begin // Round towards -∞
                    if (S_result == 1 && M_Div_25bit == 1) begin
                        M_Div_25bit = M_Div_25bit + 1;
                    end
                end
                2'b10: begin // Round towards nearest even
                    if (M_Div_25bit[1:0] == 2'b11) begin
                        M_Div_25bit = M_Div_25bit + 1;
                    end
                end
                2'b11: begin // Rounding ties away from zero
                    if (S_result == 0 && M_Div_25bit == 1) begin
                        M_Div_25bit = M_Div_25bit + 1;
                    end
                    else if (S_result == 1 && M_Div_25bit == 1) begin
                        M_Div_25bit = M_Div_25bit + 1;
                    end
                end
            endcase

            // Final normalization
            if (M_Div_25bit[24]) begin
                M_Div_25bit = M_Div_25bit >> 1;
                E_result = E_result + 1;
            end

            // Final overflow and error handling
            if (E_result >= 255) begin
                resultDiv = {S_result, 8'hFF, 23'h0}; // Set to max value on overflow
                overflowDiv = 1;
                errorDiv = 0;
            end else if (E_result <= 0) begin
                resultDiv = {S_result, 8'h00, 23'h0}; // Set to zero on underflow
                overflowDiv = 0;
                errorDiv = 0;
            end else begin
                resultDiv = {S_result, E_result[7:0], M_Div_25bit[22:0]};
                overflowDiv = 0;
                errorDiv = 0;
            end
        end
    end
endmodule
