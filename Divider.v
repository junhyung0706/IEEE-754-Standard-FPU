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
        // Division by zero = NaN
        if (E2 == 8'b0000_0000 && F2 == 23'b0000_0000_0000_0000_0000_000) begin
            resultDiv = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000}; // NaN
            errorDiv = 1;
            overflowDiv = 0;
        // Both A and B are infinity
        end else if (E1 == 8'b1111_1111 && E2 == 8'b1111_1111 && F1 == 23'b000_0000_0000_0000_0000_0000 && F2 == 23'b000_0000_0000_0000_0000_0000) begin 
            resultDiv = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000}; // NaN
            errorDiv = 1;
            overflowDiv = 0;
        // Other infinities or NaNs
        end else if ((E1 == 8'b1111_1111 && F1 != 23'b000_0000_0000_0000_0000_0000) || 
                     (E2 == 8'b1111_1111 && F2 != 23'b000_0000_0000_0000_0000_0000)) begin
            resultDiv = {S_result, 8'b1111_1111, 23'b100_0000_0000_0000_0000_0000}; // NaN
            errorDiv = 1;
            overflowDiv = 0;
        end else begin
            // Normalized number calculation: calculate mantissas with implicit leading 1
            M1 = (E1 == 8'b0000_0000) ? {1'b0, F1} : {1'b1, F1};
            M2 = (E2 == 8'b0000_0000) ? {1'b0, F2} : {1'b1, F2};

            // Exponent calculation
            E_result = E1 - E2 + 127 - 1;

            // Mantissa division
            M1_ext = M1 << 24; // Convert to extended fixed-point format
            M2_ext = M2;
            M_div_ext = M1_ext / M2_ext;
            M_div = M_div_ext[23:0]; // Truncate to 24 bits

            // Normalization and rounding
            shift_count = 0;
            while (M_div[23] == 0 && E_result > 0) begin
                M_div = M_div << 1;
                E_result = E_result - 1;
                shift_count = shift_count + 1;
            end

            // Rounding logic based on rounding mode
            case (round_mode)
                2'b00: if (M_div_ext[23]) M_div = M_div + 1; // Round to nearest even
                2'b01: if (S_result == 1 && M_div_ext[23]) M_div = M_div + 1; // Round toward negative infinity
                2'b10: if (S_result == 0 && M_div_ext[23]) M_div = M_div + 1; // Round toward positive infinity
                2'b11: if (M_div_ext[23] && (M_div_ext[22] || |M_div_ext[21:0])) M_div = M_div + 1; // Round to nearest
            endcase

            // Final normalization
            if (M_div[23]) begin
                M_div = M_div >> 1;
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
                resultDiv = {S_result, E_result[7:0], M_div[22:0]};
                overflowDiv = 0;
                errorDiv = 0;
            end
        end
    end
endmodule
