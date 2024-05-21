module FPU(
    input clk, reset,
    input [31:0] A, B,
    input [1:0] sel, round_mode,
    input start,
    output reg error, overflow,
    output reg [31:0] Y
);

    // 파이프라인 레지스터 선언
    reg [31:0] A_reg [0:2];
    reg [31:0] B_reg [0:2];
    reg [1:0] sel_reg [0:2];
    reg start_reg [0:2];

    wire [31:0] resultAddSub, resultMul, resultDiv;
    wire addSub_overflow, addSub_underflow;
    wire mul_overflow, mul_underflow;
    wire div_overflow, div_underflow;

    // 각 연산 모듈 인스턴스화 (파이프라인 버전)
    Adder_Subtractor_Pipeline addSub0(clk, A_reg[2], B_reg[2], sel_reg[2][0], resultAddSub, addSub_overflow, addSub_underflow);
    Multiplier_Pipeline mul0(clk, A_reg[2], B_reg[2], resultMul, mul_overflow, mul_underflow);
    Divider_Pipeline div0(clk, A_reg[2], B_reg[2], resultDiv, div_overflow, div_underflow);

    integer i;

    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 3; i = i + 1) begin
                A_reg[i] <= 0;
                B_reg[i] <= 0;
                sel_reg[i] <= 0;
                start_reg[i] <= 0;
            end
            error <= 0;
            overflow <= 0;
            Y <= 0;
        end else begin
            for (i = 2; i > 0; i = i - 1) begin
                A_reg[i] <= A_reg[i-1];
                B_reg[i] <= B_reg[i-1];
                sel_reg[i] <= sel_reg[i-1];
                start_reg[i] <= start_reg[i-1];
            end
            A_reg[0] <= A;
            B_reg[0] <= B;
            sel_reg[0] <= sel;
            start_reg[0] <= start;
        end
    end

    always @(posedge clk) begin
        if (start_reg[2]) begin
            case (sel_reg[2])
                2'b00, 2'b01: begin
                    Y <= resultAddSub;
                    overflow <= addSub_overflow;
                    error <= addSub_underflow;
                end
                2'b10: begin
                    Y <= resultMul;
                    overflow <= mul_overflow;
                    error <= mul_underflow;
                end
                2'b11: begin
                    Y <= resultDiv;
                    overflow <= div_overflow;
                    error <= div_underflow;
                end
                default: begin
                    Y <= 0;
                    error <= 1;
                    overflow <= 0;
                end
            endcase
        end
    end
endmodule
