`timescale 1ns/1ps
module tb_fcvt_s_w;
    reg clk;
    reg rst_n;
    reg valid_input;
    reg [31:0] a;
    wire valid_output;
    wire [31:0] y;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    fcvt_s_w uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input),
        .a(a),
        .valid_output(valid_output),
        .y(y)
    );

    initial begin
        rst_n = 0;
        valid_input = 0;
        a = 0;
        #20 rst_n = 1;
        #10 valid_input = 1; a = 32'd1;
        #20 a = -32'd1;
        #20 a = 32'd123456;
        #20 a = -32'd999999;
        #20 valid_input = 0;
        #50 $finish;
    end
endmodule
