module FPU(
    input clk, reset,
    input [31:0] A, B,
    input [1:0] sel, round_mode,
    input start,
    output reg error, overflow,
    output reg [31:0] Y
);

    reg [31:0] A_reg [0:5];
    reg [31:0] B_reg [0:5];
    reg [1:0] sel_reg [0:5];
    reg [1:0] round_mode_reg [0:5];
    reg start_reg [0:5];

    wire [31:0] resultAdd, resultSub, resultMul, resultDiv;
    wire errorAdd, overflowAdd, errorSub, overflowSub, errorMul, overflowMul, errorDiv, overflowDiv;

    // 연산 모듈 인스턴스화
    Adder        add0(A_reg[5], B_reg[5], round_mode_reg[5], errorAdd, overflowAdd, resultAdd);
    Subtractor   sub0(A_reg[5], B_reg[5], round_mode_reg[5], errorSub, overflowSub, resultSub);
    Multiplier   mul0(A_reg[5], B_reg[5], round_mode_reg[5], errorMul, overflowMul, resultMul);
    Divider      div0(A_reg[5], B_reg[5], round_mode_reg[5], errorDiv, overflowDiv, resultDiv);

    integer i;  // integer 변수 선언을 블록 외부로 옮김

    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 6; i = i + 1) begin
                A_reg[i] <= 0;
                B_reg[i] <= 0;
                sel_reg[i] <= 0;
                round_mode_reg[i] <= 0;
                start_reg[i] <= 0;
            end
            error <= 0;
            overflow <= 0;
            Y <= 0;
        end else begin
            // 파이프라인 스테이지 이동
            for (i = 5; i > 0; i = i - 1) begin
                A_reg[i] <= A_reg[i-1];
                B_reg[i] <= B_reg[i-1];
                sel_reg[i] <= sel_reg[i-1];
                round_mode_reg[i] <= round_mode_reg[i-1];
                start_reg[i] <= start_reg[i-1];
            end
            A_reg[0] <= A;
            B_reg[0] <= B;
            sel_reg[0] <= sel;
            round_mode_reg[0] <= round_mode;
            start_reg[0] <= start;

            // 6번째 스테이지에서 결과 출력
            if (start_reg[5]) begin
                case (sel_reg[5])
                    2'b00: begin
                        Y <= resultAdd;
                        error <= errorAdd;
                        overflow <= overflowAdd;
                    end
                    2'b01: begin
                        Y <= resultSub;
                        error <= errorSub;
                        overflow <= overflowSub;
                    end
                    2'b10: begin
                        Y <= resultMul;
                        error <= errorMul;
                        overflow <= overflowMul;
                    end
                    2'b11: begin
                        Y <= resultDiv;
                        error <= errorDiv;
                        overflow <= overflowDiv;
                    end
                    default: begin
                        Y <= 0;
                        error <= 1;
                        overflow <= 0;
                    end
                endcase
            end
        end
    end

endmodule
