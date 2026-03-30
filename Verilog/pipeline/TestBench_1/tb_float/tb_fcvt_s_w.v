`timescale 1ns/1ps
module tb_fcvt_s_w;
    reg clk;
    reg rst_n;
    reg valid_input;
    reg signed [31:0] a;
    wire valid_output;
    wire [31:0] y;

    fcvt_s_w uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input),
        .a(a),
        .valid_output(valid_output),
        .y(y)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; valid_input = 0; a = 0;
        #12 rst_n = 1;

        // Test số 0
        #10 valid_input = 1; a = 0;
        #10 valid_input = 0;

        // Test số dương +12
        #20 valid_input = 1; a = 32'd12;
        #10 valid_input = 0;

        // Test số âm -20
        #20 valid_input = 1; a = -32'd20;
        #10 valid_input = 0;

        #30 $finish;
    end
endmodule
