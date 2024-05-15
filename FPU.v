module FPU(
    input clk, reset,
    input [31:0] A, B,
    input [1:0] sel, round_mode,
    input start,
    output reg error, overflow,
    output reg [31:0] Y
);

    wire [31:0] resultAdd, resultSub, resultMul, resultDiv;
    wire errorAdd, overflowAdd, errorSub, overflowSub, errorMul, overflowMul, errorDiv, overflowDiv;

    // 연산 모듈 인스턴스화
    Adder        add0(A, B, round_mode, errorAdd, overflowAdd, resultAdd);
    Subtractor   sub0(A, B, round_mode, errorSub, overflowSub, resultSub);
    Multiplier   mul0(A, B, round_mode, errorMul, overflowMul, resultMul);
    Divider      div0(A, B, round_mode, errorDiv, overflowDiv, resultDiv);

    // 결과 처리 블록
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            error <= 0;
            overflow <= 0;
            Y <= 0;
        end else if(start) begin
            case (sel)
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
                    Y <= Y;
                    error <= error;
                    overflow <= overflow;
                end
            endcase
        end
    end

endmodule
