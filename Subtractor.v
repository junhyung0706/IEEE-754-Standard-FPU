module Subtractor(
    input [31:0] A,
    input [31:0] B,
    input [1:0] round_mode,
    output reg errorSub,
    output reg overflowSub,
    output reg [31:0] resultSub
);

    reg S1, S2, S_result;
    reg [7:0] E1, E2, E_result;
    reg [22:0] F1, F2;
    reg [23:0] M1, M2;
    reg [24:0] M_diff; // 25-bit mantissa result (includes overflow handling)
    reg borrow; // borrow from the subtraction
    integer shift;

    always @ (*) begin
        // Decode input signals
        S1 = A[31];
        S2 = B[31] ^ 1'b1; // Invert B's sign bit for subtraction
        E1 = A[30:23];
        E2 = B[30:23];
        F1 = A[22:0];
        F2 = B[22:0];

        // Handle special cases for NaN or Infinite inputs
        if ((E1 == 8'hFF) || (E2 == 8'hFF)) begin // Check for NaN or Infinity in inputs
            if ((E1 == 8'hFF && F1 != 0) || (E2 == 8'hFF && F2 != 0)) begin
                resultSub = (F1 != 0) ? A : B; // Propagate NaN
                errorSub = 1;
                overflowSub = 0;
            end else if (E1 == 8'hFF && E2 == 8'hFF && S1 == S2) begin
                resultSub = {1'b0, 8'hFF, 23'h400000}; // Result is NaN if infinities with same sign
                errorSub = 1;
                overflowSub = 0;
            end else if (E1 == 8'hFF) begin
                resultSub = A; // Propagate infinity from A
                errorSub = 0;
                overflowSub = 0;
            end else begin
                resultSub = {S2, 8'hFF, 23'h0}; // Propagate infinity from B (with sign inverted)
                errorSub = 0;
                overflowSub = 0;
            end
        end else begin
            // Compute mantissas with implicit leading one
            M1 = {1'b1, F1};
            M2 = {1'b1, F2};

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

            // Perform subtraction of mantissas
            if (S1 == S2) begin
                {borrow, M_diff} = M1 + M2; // Add mantissas if signs are same (because sign of B is inverted)
                S_result = S1;
            end else begin
                if (M1 >= M2) begin
                    M_diff = M1 - M2;
                    S_result = S1;
                end else begin
                    M_diff = M2 - M1;
                    S_result = S2;
                end
            end

            // Normalize and handle rounding
            if (M_diff[24]) begin
                M_diff = M_diff >> 1;
                E_result = E_result + 1;
            end

            // Rounding logic based on rounding mode
            case (round_mode)
                2'b00: if (S_result == 0 && M_diff[0]) M_diff = M_diff + 1;
                2'b01: if (S_result == 1 && M_diff[0]) M_diff = M_diff + 1;
                2'b10: if (M_diff[0] && (M_diff[1] || |M_diff[22:1])) M_diff = M_diff + 1;
                2'b11: if (M_diff[0]) M_diff = M_diff + 1;
            endcase

            // Final normalization
            if (M_diff[24]) begin
                M_diff = M_diff >> 1;
                E_result = E_result + 1;
            end

            // Final overflow and error handling
            if (E_result >= 255) begin
                resultSub = {S_result, 8'hFF, 23'h0}; // Set to max value on overflow
                overflowSub = 1;
                errorSub = 1;
            end else begin
                resultSub = {S_result, E_result[7:0], M_diff[22:0]};
                overflowSub = 0;
                errorSub = 0;
            end
        end
    end
endmodule
