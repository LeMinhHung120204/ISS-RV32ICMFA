`timescale 1ns/1ps
module tb_fcvt_s_wu;
    reg clk, rst_n, valid_input;
    reg [31:0] a;
    wire valid_output;
    wire [31:0] y;

    fcvt_s_wu uut (
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

        valid_input = 1; a = 32'd0; #10;
        valid_input = 1; a = 32'd1; #10;
        valid_input = 1; a = 32'd99999; #10;
        valid_input = 1; a = 32'hFFFFFFFF; #10;
        valid_input = 0;

        #100;
        $finish;
    end
endmodule
