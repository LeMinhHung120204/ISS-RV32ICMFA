`timescale 1ns/1ps
module tb_fcvt_wu_s;
    reg clk, rst_n, valid_input;
    reg [31:0] a;
    wire valid_output;
    wire [31:0] y;

    fcvt_wu_s uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input),
        .a(a),
        .valid_output(valid_output),
        .y(y)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        valid_input = 0;
        a = 0;
        #30;
        rst_n = 1;

        valid_input = 1; a = 32'h3F800000; #10; // +1.0
        valid_input = 1; a = 32'h40000000; #10; // +2.0
        valid_input = 1; a = 32'h41200000; #10; // +10.0
        valid_input = 1; a = 32'hC2480000; #10; // -50.0
        valid_input = 1; a = 32'h7F800000; #10; // +Inf
        valid_input = 0;

        #100;
        $finish;
    end
endmodule
