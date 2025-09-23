`timescale 1ns/1ps
module MEM_WB #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] M_ALUResult, M_ReadData, M_ImmExt, M_MulOut, M_quotient, M_remainder,
    input [ADDR_WIDTH - 1:0] M_PCPlus4, M_PCTarget,
    input [4:0] M_Rd,
    input [2:0] M_ResultSrc,
    input M_RegWrite, 
    
    output [DATA_WIDTH - 1:0] W_ALUResult, W_ReadData, W_ImmExt, W_MulOut, W_quotient, W_remainder,
    output [ADDR_WIDTH - 1:0] W_PCPlus4, W_PCTarget,
    output [4:0] W_Rd,
    output [2:0] W_ResultSrc,
    output W_RegWrite
);
    reg [DATA_WIDTH - 1:0] reg_ALUResultW, reg_ReadDataW, reg_ImmExtW, reg_MulOutW, reg_quotientW, reg_remainderW;
    reg [ADDR_WIDTH - 1:0] reg_PCPlus4W, reg_PCTargetW;
    reg [4:0] reg_rdW;
    reg [2:0] reg_ResultSrcW;
    reg reg_RegWriteW;
    

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_ALUResultW  <= 32'd0; 
            reg_ReadDataW   <= 32'd0;
            reg_ImmExtW     <= 32'd0;
            reg_PCTargetW   <= 32'd0;
            reg_PCPlus4W    <= 32'd0;
            reg_MulOutW     <= 32'd0;
            reg_quotientW   <= 32'd0;
            reg_remainderW  <= 32'd0;
            reg_rdW         <= 5'd0;
            reg_RegWriteW   <= 1'b0;
            reg_ResultSrcW  <= 3'b0;
        end 
        else begin
            reg_ALUResultW  <= M_ALUResult; 
            reg_ReadDataW   <= M_ReadData;
            reg_ImmExtW     <= M_ImmExt;
            reg_PCTargetW   <= M_PCTarget;
            reg_PCPlus4W    <= M_PCPlus4;
            reg_MulOutW     <= M_MulOut;
            reg_quotientW   <= M_quotient;
            reg_remainderW  <= M_remainder;
            reg_rdW         <= M_Rd;
            reg_RegWriteW   <= M_RegWrite;
            reg_ResultSrcW  <= M_ResultSrc;
        end 
    end 

    assign W_ALUResult  = reg_ALUResultW;
    assign W_ReadData   = reg_ReadDataW;
    assign W_ImmExt     = reg_ImmExtW;
    assign W_PCTarget   = reg_PCTargetW;
    assign W_PCPlus4    = reg_PCPlus4W;
    assign W_MulOut     = reg_MulOutW;
    assign W_quotient   = reg_quotientW;
    assign W_remainder  = reg_remainderW;
    assign W_Rd         = reg_rdW;
    assign W_RegWrite   = reg_RegWriteW;
    assign W_ResultSrc  = reg_ResultSrcW;
endmodule