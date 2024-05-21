module Booth_Multiplier(
    input [23:0] A, B,
    output reg [47:0] product
);

    reg [47:0] multiplicand;
    reg [47:0] multiplier;
    reg [47:0] result;
    reg [5:0] count;

    always @(*) begin
        multiplicand = {24'b0, A}; // 48��Ʈ�� Ȯ��
        multiplier = {B, 24'b0}; // 48��Ʈ�� Ȯ��
        result = 48'b0;
        count = 6'd24; // 24��Ʈ �����̹Ƿ� 24�� �ݺ�

        while (count > 0) begin
            if (multiplier[1:0] == 2'b01) begin
                result = result + multiplicand;
            end else if (multiplier[1:0] == 2'b10) begin
                result = result - multiplicand;
            end

            multiplicand = multiplicand << 1;
            multiplier = multiplier >> 1;

            count = count - 1;
        end

        product = result;
    end
endmodule
