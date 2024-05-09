module tb_Adder;
    reg [31:0] A;
    reg [31:0] B;
    reg [1:0] round_mode;
    wire errorAdd;
    wire overflowAdd;
    wire [31:0] resultAdd;
    
    Adder Adder0(A,B,round_mode,errorAdd,overflowAdd,resultAdd);
    
    initial begin
        A = 32'b0_10000010_11110000000000000000000;
        B = 32'b0_01111110_00100000000000000110000;
        round_mode = 2'b00;
        #10;
        round_mode = 2'b01;
        #10;
        round_mode = 2'b10;
        #10
        round_mode = 2'b11;
        #30;
        $finish;
    end
    
endmodule
