module Divider_Pipeline(
    input clk,
    input [31:0] A, B,
    output reg [31:0] result,
    output reg overflow,
    output reg underflow
);

    // �������� �������� ����
    reg sign_A, sign_B, sign_result;
    reg [7:0] exp_A, exp_B, exp_diff, exp_result;
    reg [23:0] man_A, man_B, man_result;
    reg [47:0] man_quotient;
    reg [31:0] Y0, Y1, Y2; // ����-���� �ݺ� ����� ���� �ٻ簪

    always @(posedge clk) begin
        // Stage 1: ��ȣ ��Ʈ ó�� �� ���� ���� ���
        sign_A <= A[31];
        sign_B <= B[31];
        exp_A <= A[30:23];
        exp_B <= B[30:23];
        man_A <= {1'b1, A[22:0]};
        man_B <= {1'b1, B[22:0]};
        sign_result <= sign_A ^ sign_B;
        exp_diff <= exp_A - exp_B + 8'd127; // ������ ���� ���

        // Stage 2: �ʱ� �ٻ簪 Y0 ���
        if (B[30:23] == 8'h0) begin
            // B�� 0�� ��� ���� ó�� (������ �Ұ�)
            Y0 <= 32'h7FFFFFFF; // �ִ밪���� ����
        end else begin
            // �ʱ� �ٻ簪 Y0 ���� (�⺻������ ������ �ʱ� �ٻ簪���� ����)
            Y0 <= 32'h4C000000 - (B[30:23] << 23);
        end

        // Stage 3: ù ��° �ݺ� ���
        Y1 <= Y0 * (48'h100000000 - (man_B * Y0) >> 24);

        // Stage 4: �� ��° �ݺ� ���
        Y2 <= Y1 * (48'h100000000 - (man_B * Y1) >> 24);

        // Stage 5: ���� �ٻ簪 ��� �� ����
        man_quotient <= man_A * Y2;

        // Stage 6: ����ȭ �� ��� ����
        if (man_quotient[47]) begin
            man_result <= man_quotient[46:24];
            exp_result <= exp_diff + 1;
        end else begin
            man_result <= man_quotient[45:23];
            exp_result <= exp_diff;
        end

        // Overflow �� Underflow üũ
        overflow <= (exp_result >= 8'hFF);
        underflow <= (exp_result <= 8'h00);

        // ��� ���
        if (overflow) begin
            result <= {sign_result, 8'hFF, 23'h0}; // Infinity
        end else if (underflow) begin
            result <= {sign_result, 8'h00, 23'h0}; // Zero
        end else begin
            result <= {sign_result, exp_result[7:0], man_result[22:0]};
        end
    end
endmodule
