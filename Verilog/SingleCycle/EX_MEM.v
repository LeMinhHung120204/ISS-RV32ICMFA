`timescale 1ns/1ps
module EX_MEM #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] ALUResultE, WriteDataE,
    input [ADDR_WIDTH - 1:0] PCPlus4E,
    input RegWriteE, MemWriteE,
    input [1:0] ResultSrcE,
    output [DATA_WIDTH - 1:0] ALUResultM, WriteDataM,
    output [ADDR_WIDTH - 1:0] PCPlus4M,
    output RegWriteM, MemWriteM,
    output [1:0] ResultSrcM,
);
    reg [DATA_WIDTH - 1:0] reg_ALUResultM, reg_WriteDataM;
    reg [ADDR_WIDTH - 1:0] reg_PCPlus4M;
    reg reg_RegWriteM, reg_MemWriteM,
    reg [1:0] reg_ResultSrcM,
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_ALUResultM  <= 32'd0;
            reg_WriteDataM  <= 32'd0;
            reg_PCPlus4M    <= 32'd0;
            reg_RegWriteM   <= 1'b0;
            reg_MemWriteM   <= 1'b0;
            reg_ResultSrcM  <= 2'b0;
        end 
        else begin
            reg_ALUResultM  <= ALUResultE;
            reg_WriteDataM  <= WriteDataE
            reg_PCPlus4M    <= PCPlus4E;
            reg_RegWriteM   <= RegWriteE;
            reg_MemWriteM   <= MemWriteE;
            reg_ResultSrcM  <= ResultSrcE;
        end 
    end 

    assign ALUResultM = reg_ALUResultM;
    assign WriteDataM = reg_WriteDataM;
    assign PCPlus4M = reg_PCPlus4M;
    assign RegWriteM = reg_RegWriteM;
    assign MemWriteM = reg_MemWriteM;
    assign ResultSrcM = reg_ResultSrcM;
endmodule