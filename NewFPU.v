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

    reg [31:0] add_result [0:5];
    reg add_error [0:5];
    reg add_overflow [0:5];
    reg [31:0] sub_result [0:5];
    reg sub_error [0:5];
    reg sub_overflow [0:5];
    reg [31:0] mul_result [0:5];
    reg mul_error [0:5];
    reg mul_overflow [0:5];
    reg [31:0] div_result [0:5];
    reg div_error [0:5];
    reg div_overflow [0:5];

    integer i;  // integer 변수 선언을 블록 외부로 옮김

    // 파이프라인 초기화 및 이동
    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 6; i = i + 1) begin
                A_reg[i] <= 0;
                B_reg[i] <= 0;
                sel_reg[i] <= 0;
                round_mode_reg[i] <= 0;
                start_reg[i] <= 0;
                add_result[i] <= 0;
                add_error[i] <= 0;
                add_overflow[i] <= 0;
                sub_result[i] <= 0;
                sub_error[i] <= 0;
                sub_overflow[i] <= 0;
                mul_result[i] <= 0;
                mul_error[i] <= 0;
                mul_overflow[i] <= 0;
                div_result[i] <= 0;
                div_error[i] <= 0;
                div_overflow[i] <= 0;
            end
            error <= 0;
            overflow <= 0;
            Y <= 0;
        end else begin
            for (i = 5; i > 0; i = i - 1) begin
                A_reg[i] <= A_reg[i-1];
                B_reg[i] <= B_reg[i-1];
                sel_reg[i] <= sel_reg[i-1];
                round_mode_reg[i] <= round_mode_reg[i-1];
                start_reg[i] <= start_reg[i-1];
                add_result[i] <= add_result[i-1];
                add_error[i] <= add_error[i-1];
                add_overflow[i] <= add_overflow[i-1];
                sub_result[i] <= sub_result[i-1];
                sub_error[i] <= sub_error[i-1];
                sub_overflow[i] <= sub_overflow[i-1];
                mul_result[i] <= mul_result[i-1];
                mul_error[i] <= mul_error[i-1];
                mul_overflow[i] <= mul_overflow[i-1];
                div_result[i] <= div_result[i-1];
                div_error[i] <= div_error[i-1];
                div_overflow[i] <= div_overflow[i-1];
            end
            A_reg[0] <= A;
            B_reg[0] <= B;
            sel_reg[0] <= sel;
            round_mode_reg[0] <= round_mode;
            start_reg[0] <= start;
        end
    end

    // 각 연산 모듈 파이프라인 스테이지
    always @(posedge clk) begin
        if (start_reg[0]) begin
            add_result[0] <= A_reg[0] + B_reg[0];
            add_error[0] <= 0;
            add_overflow[0] <= 0;
            sub_result[0] <= A_reg[0] - B_reg[0];
            sub_error[0] <= 0;
            sub_overflow[0] <= 0;
            mul_result[0] <= A_reg[0] * B_reg[0];
            mul_error[0] <= 0;
            mul_overflow[0] <= 0;
            if (B_reg[0] == 0) begin
                div_result[0] <= 32'hFFFFFFFF;  // Div by 0 error
                div_error[0] <= 1;
                div_overflow[0] <= 1;
            end else begin
                div_result[0] <= A_reg[0] / B_reg[0];
                div_error[0] <= 0;
                div_overflow[0] <= 0;
            end
        end

        for (i = 1; i < 6; i = i + 1) begin
            if (start_reg[i]) begin
                add_result[i] <= add_result[i-1];
                add_error[i] <= add_error[i-1];
                add_overflow[i] <= add_overflow[i-1];
                sub_result[i] <= sub_result[i-1];
                sub_error[i] <= sub_error[i-1];
                sub_overflow[i] <= sub_overflow[i-1];
                mul_result[i] <= mul_result[i-1];
                mul_error[i] <= mul_error[i-1];
                mul_overflow[i] <= mul_overflow[i-1];
                div_result[i] <= div_result[i-1];
                div_error[i] <= div_error[i-1];
                div_overflow[i] <= div_overflow[i-1];
            end
        end
    end

    // 6번째 스테이지에서 결과 출력
    always @(posedge clk) begin
        if (start_reg[5]) begin
            case (sel_reg[5])
                2'b00: begin
                    Y <= add_result[5];
                    error <= add_error[5];
                    overflow <= add_overflow[5];
                end
                2'b01: begin
                    Y <= sub_result[5];
                    error <= sub_error[5];
                    overflow <= sub_overflow[5];
                end
                2'b10: begin
                    Y <= mul_result[5];
                    error <= mul_error[5];
                    overflow <= mul_overflow[5];
                end
                2'b11: begin
                    Y <= div_result[5];
                    error <= div_error[5];
                    overflow <= div_overflow[5];
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
