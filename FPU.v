module FPU(
    input clk, reset,
    input [31:0] A, B,
    input [1:0] sel, round_mode,
    input start,
    output reg error, overflow,
    output reg [31:0] Y

);

    wire [31:0] tempResult;

    //A와 B의 연산을 수행
    always @(posedge clk or posedge reset) begin
        if (reset) begin    //리셋이 있을 때 결과 값들 초기화
            error <= 0;
            overflow <= 0;
            Y <= 0;
        end
        else if(start) begin //시작이 있을 때 연산 수행
            case (sel)
                2'b00: Adder        Add0(A, B, round_mode, error, overflow, tempResult);
                2'b01: Subtractor   Sub0(A, B, round_mode, error, overflow, tempResult);
                2'b10: Multiplier   Mul0(A, B, round_mode, error, overflow, tempResult);
                2'b11: Divider      Div0(A, B, round_mode, error, overflow, tempResult);
                default: 
            endcase
        end 
        else begin
            error <= error;
            overflow <= overflow;
            Y <= Y;
        end
    end

endmodule
