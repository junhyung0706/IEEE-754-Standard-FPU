module Adder_Subtractor_Pipeline(
    input clk,
    input [31:0] A, B,
    input is_sub, // 0 for addition, 1 for subtraction
    output reg [31:0] result,
    output reg overflow,
    output reg underflow
);

    // �������� �������� ����
    reg sign_A, sign_B, sign_result;
    reg [7:0] exp_A, exp_B, exp_diff, exp_result;
    reg [23:0] man_A, man_B, man_result;
    reg [24:0] aligned_man_A, aligned_man_B, man_sum;
    reg [7:0] exp_max;
    reg is_sub_stage;

    always @(posedge clk) begin
        // Stage 1: ��ȣ ��Ʈ�� ���� �и�
        sign_A <= A[31];
        sign_B <= is_sub ? ~B[31] : B[31]; // ������ ��� B�� ��ȣ�� ����
        exp_A <= A[30:23];
        exp_B <= B[30:23];
        man_A <= {1'b1, A[22:0]};
        man_B <= {1'b1, B[22:0]};
        is_sub_stage <= is_sub;

        // Stage 2: ���� ����
        if (exp_A > exp_B) begin
            exp_diff <= exp_A - exp_B;
            exp_max <= exp_A;
            aligned_man_A <= {1'b1, A[22:0]};
            aligned_man_B <= {1'b1, B[22:0]} >> (exp_A - exp_B);
        end else begin
            exp_diff <= exp_B - exp_A;
            exp_max <= exp_B;
            aligned_man_A <= {1'b1, A[22:0]} >> (exp_B - exp_A);
            aligned_man_B <= {1'b1, B[22:0]};
        end

        // Stage 3: ���� �Ǵ� ����
        if (sign_A == sign_B) begin
            man_sum <= aligned_man_A + aligned_man_B;
            sign_result <= sign_A;
        end else begin
            if (aligned_man_A >= aligned_man_B) begin
                man_sum <= aligned_man_A - aligned_man_B;
                sign_result <= sign_A;
            end else begin
                man_sum <= aligned_man_B - aligned_man_A;
                sign_result <= sign_B;
            end
        end

        // Stage 4: ����ȭ
        if (man_sum[24]) begin
            man_result <= man_sum[24:1];
            exp_result <= exp_max + 1;
        end else if (man_sum[23]) begin
            man_result <= man_sum[23:0];
            exp_result <= exp_max;
        end else begin
            // ����ȭ �ʿ� (���⼭�� ������ ó��)
            man_result <= man_sum[22:0];
            exp_result <= exp_max - 1;
        end

        // Overflow �� Underflow üũ
        overflow <= (exp_result >= 8'hFF);
        underflow <= (exp_result <= 8'h00);

        // Stage 5: ��� ����
        if (overflow) begin
            result <= {sign_result, 8'hFF, 23'h0}; // Infinity
        end else if (underflow) begin
            result <= {sign_result, 8'h00, 23'h0}; // Zero
        end else begin
            result <= {sign_result, exp_result[7:0], man_result[22:0]};
        end
    end
endmodule
