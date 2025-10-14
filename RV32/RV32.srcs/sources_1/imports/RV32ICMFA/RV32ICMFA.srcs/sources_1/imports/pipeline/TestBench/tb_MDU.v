`timescale 1ns/1ps
module tb_MDU;
    parameter WIDTH = 32;
    reg clk, rst_n, is_high;
    reg [1:0]   Mul_Div_unsigned;
    reg [2:0]   funct3;
    reg [10:0]  count_clock;
    reg [WIDTH - 1:0] rs1, rs2, rd;
    
    wire [WIDTH - 1:0] OutData;

    MDU mul_inst(
        .clk(clk),
        .rst_n(rst_n),
        .is_high(is_high),
        .Mul_Div_unsigned(Mul_Div_unsigned),
        .funct3(funct3),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .OutData(OutData)
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
        is_high = 0;
        Mul_Div_unsigned = 2'b00;
        funct3 = 3'b000;
        rs1 = 32'd0;
        rs2 = 32'd0;
        rd = 32'd0;

        #30;
        rst_n = 1;
        funct3 = 3'd6;
        rs1 = 32'd3;
        rs2 = 32'd5;
        rd = 32'd10;
        #100;
    end
endmodule