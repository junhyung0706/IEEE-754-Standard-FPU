module Adder(
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorAdd,
    output reg overflowAdd,
    output reg [31:0] resultAdd
);

    reg S1, S2, S_result;
    reg [7:0] E1, E2;
    reg [8:0] E_result; // 1 extra bit to handle overflow
    reg [22:0] F1, F2;
    reg [23:0] M1, M2;
    reg [24:0] M_sum; // 25-bit mantissa result (includes overflow handling)
    integer shift;

    always @ (*) begin
        // Decode input signals
        S1 = A[31];
        S2 = B[31];
        E1 = A[30:23];
        E2 = B[30:23];
        F1 = A[22:0];
        F2 = B[22:0];

        // Exception Handling
        if ((E1 == 8'hFF) || (E2 == 8'hFF)) begin // Check for NaN or Infinity in inputs
            if ((E1 == 8'hFF && F1 != 0) || (E2 == 8'hFF && F2 != 0)) begin
                resultAdd = (F1 != 0) ? A : B; // Propagate NaN
                errorAdd = 1;
                overflowAdd = 0;
            end else if (E1 == 8'hFF && E2 == 8'hFF) begin
                if (S1 != S2) begin
                    resultAdd = {1'b0, 8'hFF, 23'h400000}; // Result is NaN if infinities with different sign
                    errorAdd = 1;
                    overflowAdd = 0;
                end else begin
                    resultAdd = A; // Propagate infinity with A's sign
                    errorAdd = 0;
                    overflowAdd = 1;
                end
            end else if (E1 == 8'hFF) begin
                resultAdd = A; // Propagate infinity from A
                errorAdd = 0;
                overflowAdd = 1;
            end else begin
                resultAdd = B; // Propagate infinity from B
                errorAdd = 0;
                overflowAdd = 1;
            end
        end else begin
            // Compute mantissas with implicit leading one only if input is normalized
            M1 = E1 ? {1'b1, F1} : 24'b0;
            M2 = E2 ? {1'b1, F2} : 24'b0;

            // Align mantissas based on exponent difference
            if (E1 > E2) begin
                shift = E1 - E2;
                M2 = M2 >> shift;
                E_result = E1;
            end else begin
                shift = E2 - E1;
                M1 = M1 >> shift;
                E_result = E2;
            end

            // Perform addition or subtraction of mantissas based on the signs of inputs
            if (S1 == S2) begin
                M_sum = M1 + M2;
                S_result = S1;
            end else begin
                if (M1 >= M2) begin
                    M_sum = M1 - M2; // Perform subtraction if signs are different
                    S_result = S1;
                end else begin
                    M_sum = M2 - M1;
                    S_result = S2;
                end
            end

            // Normalize and handle rounding
            if (M_sum[24]) begin
                M_sum = M_sum >> 1;
                E_result = E_result + 1;
            end else begin
                while (M_sum[23] == 0 && E_result > 0) begin
                    M_sum = M_sum << 1;
                    E_result = E_result - 1;
                end
            end

            // Rounding logic based on rounding mode
            case (round_mode)
                2'b00: if (S_result == 0 && M_sum[0]) M_sum = M_sum + 1;
                2'b01: if (S_result == 1 && M_sum[0]) M_sum = M_sum + 1;
                2'b10: if (M_sum[0] && (M_sum[1] || |M_sum[22:1])) M_sum = M_sum + 1;
                2'b11: if (M_sum[0]) M_sum = M_sum + 1;
            endcase

            // Final normalization
            if (M_sum[24]) begin
                M_sum = M_sum >> 1;
                E_result = E_result + 1;
            end

            // Final Exception handling
            if (E_result >= 255) begin
                resultAdd = {S_result, 8'hFF, 23'h0}; // Set to infinity on overflow
                overflowAdd = 1;
                errorAdd = 0;
            end else if (E_result == 0) begin
                resultAdd = {S_result, 31'h0}; // Set to signed zero on underflow
                overflowAdd = 0;
                errorAdd = 0;
            end else begin
                resultAdd = {S_result, E_result[7:0], M_sum[22:0]};
                overflowAdd = 0;
                errorAdd = 0;
            end
        end
    end
endmodule
