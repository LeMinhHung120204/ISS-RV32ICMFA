`timescale 1ns/1ps
module tb_mul;
    parameter WIDTH = 32;
    reg clk, rst_n, is_unsigned;
    reg [WIDTH - 1:0] a, b;
    reg [10:0] count_clock;
    wire [(WIDTH * 2)-1:0] res;

    mul32 mul_inst(
        .clk(clk),
        .rst_n(rst_n),
        .is_unsigned(is_unsigned),
        .a(a),
        .b(b),
        .R(res)
    );

    always #5 clk = ~clk;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            count_clock <= 11'd0;
        end 
        else begin
            count_clock <= count_clock + 1'b1;
        end 
    end 

    initial begin
        clk = 0;
        rst_n = 0;
        is_unsigned = 0;

        #30;
        rst_n = 1;
        a = 32'd3;
        b = -32'd2;
        #10;
        rst_n = 1;
        a = 32'd123;
        b = -32'd2;
        
        #10;
        rst_n = 1;
        a = -32'd123;
        b = -32'd123;
        #100;
    end
endmodule