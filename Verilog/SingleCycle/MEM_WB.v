`timescale 1ns/1ps
module MEM_WB #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] ALUResultM, ReadDataM,
    input [ADDR_WIDTH - 1:0] PCPlus4M, 
    input RegWriteM, 
    input [1:0] ResultSrcM,
    output [DATA_WIDTH - 1:0] ALUResultW, ReadDataW,
    output [ADDR_WIDTH - 1:0] PCPlus4W,
    output RegWriteW, 
    output [1:0] ResultSrcW,
);
    reg [DATA_WIDTH - 1:0] reg_ALUResultW, reg_ReadDataW;
    reg [ADDR_WIDTH - 1:0] reg_PCPlus4W;
    reg reg_RegWriteW, 
    reg [1:0] reg_ResultSrcW,

    always @(posedge clk or negedge) begin
        if (~rst_n) begin
            reg_ALUResultW  <= 32'd0; 
            reg_ReadDataW   <= 32'd0;
            reg_PCPlus4W    <= 32'd0;
            reg_RegWriteW   <= 1'b0;
            reg_ResultSrcW  <= 2'b0;
        end 
        else begin
            reg_ALUResultW  <= ALUResultM; 
            reg_ReadDataW   <= ReadDataM;
            reg_PCPlus4W    <= PCPlus4M;
            reg_RegWriteW   <= RegWriteM;
            ResultSrcW      <= reg_ResultSrcW;
        end 
    end 

    assign ALUResultW   = reg_ALUResultW;
    assign ReadDataW    = reg_ReadDataW;
    assign PCPlus4W     = reg_PCPlus4W;
    assign RegWriteW    = reg_RegWriteW;
    assign ResultSrcW   = reg_ResultSrcW;
endmodule