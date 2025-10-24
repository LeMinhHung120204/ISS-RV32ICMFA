`timescale 1ns/1ps
module tb_fcvt_w_s;
    reg clk;
    reg rst_n;
    reg valid_input;
    reg [31:0] a;
    wire valid_output;
    wire signed [31:0] y;

    fcvt_w_s uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input),
        .a(a),
        .valid_output(valid_output),
        .y(y)
    );

    initial begin
        clk = 0; forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; valid_input = 0; a = 0;
        #12 rst_n = 1;

        // float 0.0
        #10 valid_input = 1; a = 32'h00000000; // 0.0f
        #10 valid_input = 0;

        // float +12.123 (IEEE754 = 0x41420FAE)
        #20 valid_input = 1; a = 32'h41420FAE;
        #10 valid_input = 0;

        // float -20.789 (IEEE754 = 0xC1A64FDF)
        #20 valid_input = 1; a = 32'hC1A64FDF;
        #10 valid_input = 0;

        #30 $finish;
    end
endmodule
