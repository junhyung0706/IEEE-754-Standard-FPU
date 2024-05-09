module Goldentest;
    reg Clock, Reset;
    reg [31:0] A, B;
    reg [1:0] Sel;
    reg [1:0] round;
    wire [31:0] Y;
    wire Overflow, Error;
    parameter STEP=5;

    FPU FPU(Clock,Reset,A,B,Sel,round, start, Error,Overflow,Y);

    initial
        $monitor($time, " A = %b, B = %b, Sel = %b, Y = %b, Overflow = %b, Error = %b", A, B, Sel, Y, Overflow, Error);

    initial
    begin
        Clock = 1'b0;
        forever # (STEP/2) Clock = ~Clock;
    end

    initial begin
        Reset=1;
        A=32'b00000000000000000000000000000000;
        B=32'b00000000000000000000000000000000;
        Sel = 2'b00;
        start = 0;
        round =2'b00;
        repeat(2) @(negedge Clock); Reset = 0;
        repeat(1) @(negedge Clock);
        //arithmetic operation
        A = 32'b0_10000010_11100000000000000000000;
        B = 32'b0_10000011_11000000000000000000000;
        Sel = 2'b00;
        start = 1;
        round =2'b00;
        repeat(1) @(negedge Clock);
        repeat(10) @(negedge Clock);
    end
endmodule
