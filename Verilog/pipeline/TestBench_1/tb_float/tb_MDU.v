`timescale 1ns/1ps
module tb_MDU;
    parameter WIDTH = 32;
    reg clk, rst_n, is_high, valid_input;
    reg [1:0]   Mul_Div_unsigned;
    reg [1:0]   MulDivOp;
    reg [10:0]  count_clock;
    reg [WIDTH - 1:0] rs1, rs2, rd;
    
    wire [WIDTH - 1:0] OutData;
    wire [WIDTH-1:0] oRD;
    wire stall;

    MDU mul_inst(
        .clk(clk),
        .rst_n(rst_n),
        .is_high(is_high),
        .Mul_Div_unsigned(Mul_Div_unsigned),
        .valid_input(valid_input),
        .MulDivOp(MulDivOp),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .OutData(OutData),
        .oRD(oRD),
        .stall(stall)
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
        valid_input = 0;
        Mul_Div_unsigned = 2'b00;
//        funct3 = 3'b000;
        rs1 = 32'd0;
        rs2 = 32'd0;
        rd = 32'd0;

        #30;
        rst_n = 1;
        valid_input = 1;
        MulDivOp = 2'b00;
        rs1 = 32'd3;
        rs2 = 32'd5;
        rd = 32'd10;

        #10;
        valid_input = 0;
        #100;
    end
endmodule