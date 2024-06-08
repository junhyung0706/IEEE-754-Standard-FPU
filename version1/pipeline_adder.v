module Adder(
    input clk,
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

    // Pipeline registers for stage 1 to stage 2
    reg S1_stage2, S2_stage2;
    reg [7:0] E1_stage2, E2_stage2;
    reg [22:0] F1_stage2, F2_stage2;

    // Pipeline registers for stage 2 to stage 3
    reg S_result_stage3;
    reg [8:0] E_result_stage3;
    reg [24:0] M_sum_stage3;

    // Stage 1: Decode input signals and handle exceptions
    always @ (posedge clk) begin
        // Decode input signals
        S1 <= A[31];
        S2 <= B[31];
        E1 <= A[30:23];
        E2 <= B[30:23];
        F1 <= A[22:0];
        F2 <= B[22:0];

        // Pass values to the next stage
        S1_stage2 <= S1;
        S2_stage2 <= S2;
        E1_stage2 <= E1;
        E2_stage2 <= E2;
        F1_stage2 <= F1;
        F2_stage2 <= F2;

        // Exception Handling
        if ((E1 == 8'hFF) || (E2 == 8'hFF)) begin // Check for NaN or Infinity in inputs
            if ((E1 == 8'hFF && F1 != 0) || (E2 == 8'hFF && F2 != 0)) begin
                resultAdd <= (F1 != 0) ? A : B; // Propagate NaN
                errorAdd <= 1;
                overflowAdd <= 0;
            end else if (E1 == 8'hFF && E2 == 8'hFF) begin
                if (S1 != S2) begin
                    resultAdd <= {1'b0, 8'hFF, 23'h400000}; // Result is NaN if infinities with different sign
                    errorAdd <= 1;
                    overflowAdd <= 0;
                end else begin
                    resultAdd <= A; // Propagate infinity with A's sign
                    errorAdd <= 0;
                    overflowAdd <= 1;
                end
            end else if (E1 == 8'hFF) begin
                resultAdd <= A; // Propagate infinity from A
                errorAdd <= 0;
                overflowAdd <= 1;
            end else begin
                resultAdd <= B; // Propagate infinity from B
                errorAdd <= 0;
                overflowAdd <= 1;
            end
        end
    end

    // Stage 2: Compute mantissas, align, and perform addition or subtraction
    always @ (posedge clk) begin
        // Compute mantissas with implicit leading one only if input is normalized
        M1 <= E1_stage2 ? {1'b1, F1_stage2} : 24'b0;
        M2 <= E2_stage2 ? {1'b1, F2_stage2} : 24'b0;

        // Align mantissas based on exponent difference
        if (E1_stage2 > E2_stage2) begin
            shift <= E1_stage2 - E2_stage2;
            M2 <= M2 >> shift;
            E_result <= E1_stage2;
        end else begin
            shift <= E2_stage2 - E1_stage2;
            M1 <= M1 >> shift;
            E_result <= E2_stage2;
        end

        // Perform addition or subtraction of mantissas based on the signs of inputs
        if (S1_stage2 == S2_stage2) begin
            M_sum <= M1 + M2;
            S_result <= S1_stage2;
        end else begin
            if (M1 >= M2) begin
                M_sum <= M1 - M2; // Perform subtraction if signs are different
                S_result <= S1_stage2;
            end else begin
                M_sum <= M2 - M1;
                S_result <= S2_stage2;
            end
        end

        // Pass values to the next stage
        S_result_stage3 <= S_result;
        E_result_stage3 <= E_result;
        M_sum_stage3 <= M_sum;
    end

    // Stage 3: Normalize, handle rounding, and generate the final result
    always @ (posedge clk) begin
        // Normalize and handle rounding
        if (M_sum_stage3[24]) begin
            M_sum_stage3 <= M_sum_stage3 >> 1;
            E_result_stage3 <= E_result_stage3 + 1;
        end else begin
            while (M_sum_stage3[23] == 0 && E_result_stage3 > 0) begin
                M_sum_stage3 <= M_sum_stage3 << 1;
                E_result_stage3 <= E_result_stage3 - 1;
            end
        end

        // Rounding logic based on rounding mode
        case (round_mode)
            2'b00: if (S_result_stage3 == 0 && M_sum_stage3[0]) M_sum_stage3 <= M_sum_stage3 + 1;
            2'b01: if (S_result_stage3 == 1 && M_sum_stage3[0]) M_sum_stage3 <= M_sum_stage3 + 1;
            2'b10: if (M_sum_stage3[0] && (M_sum_stage3[1] || |M_sum_stage3[22:1])) M_sum_stage3 <= M_sum_stage3 + 1;
            2'b11: if (M_sum_stage3[0]) M_sum_stage3 <= M_sum_stage3 + 1;
        endcase

        // Final normalization
        if (M_sum_stage3[24]) begin
            M_sum_stage3 <= M_sum_stage3 >> 1;
            E_result_stage3 <= E_result_stage3 + 1;
        end

        // Final Exception handling
        if (E_result_stage3 >= 255) begin
            resultAdd <= {S_result_stage3, 8'hFF, 23'h0}; // Set to infinity on overflow
            overflowAdd <= 1;
            errorAdd <= 0;
        end else if (E_result_stage3 == 0) begin
            resultAdd <= {S_result_stage3, 31'h0}; // Set to signed zero on underflow
            overflowAdd <= 0;
            errorAdd <= 0;
        end else begin
            resultAdd <= {S_result_stage3, E_result_stage3[7:0], M_sum_stage3[22:0]};
            overflowAdd <= 0;
            errorAdd <= 0;
        end
    end
endmodule