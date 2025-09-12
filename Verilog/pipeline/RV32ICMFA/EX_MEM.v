`timescale 1ns/1ps
module EX_MEM #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input   clk, rst_n, E_RegWrite, E_MemWrite,
    input   [DATA_WIDTH - 1:0]  E_ALUResult, E_WriteData, E_ImmExt,
    input   [ADDR_WIDTH - 1:0]  E_PCPlus4, E_PCTarget,
    input   [4:0]               E_Rd,
    input   [2:0]               E_ResultSrc,

    output  [DATA_WIDTH - 1:0]  M_ALUResult, M_WriteData, M_ImmExt,
    output  [ADDR_WIDTH - 1:0]  M_PCPlus4, M_PCTarget,
    output  [4:0]               M_Rd,
    output  [2:0]               M_ResultSrc,
    output M_RegWrite, M_MemWrite
);
    reg [DATA_WIDTH - 1:0] reg_ALUResultM, reg_WriteDataM, reg_ImmExtM;
    reg [ADDR_WIDTH - 1:0] reg_PCPlus4M, reg_PCTargetM;
    reg [4:0] reg_M_rd;
    reg [2:0] reg_ResultSrcM;
    reg reg_RegWriteM, reg_MemWriteM;
    

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_ALUResultM  <= 32'd0;
            reg_WriteDataM  <= 32'd0;
            reg_ImmExtM     <= 32'd0;
            reg_PCPlus4M    <= 32'd0;
            reg_PCTargetM   <= 32'd0;
            reg_M_rd        <= 5'd0;
            reg_RegWriteM   <= 1'b0;
            reg_MemWriteM   <= 1'b0;
            reg_ResultSrcM  <= 3'b0;
        end 
        else begin
            reg_ALUResultM  <= E_ALUResult;
            reg_WriteDataM  <= E_WriteData;
            reg_ImmExtM     <= E_ImmExt;
            reg_PCPlus4M    <= E_PCPlus4;
            reg_PCTargetM   <= E_PCTarget;
            reg_M_rd        <= E_Rd;
            reg_RegWriteM   <= E_RegWrite;
            reg_MemWriteM   <= E_MemWrite;
            reg_ResultSrcM  <= E_ResultSrc;
        end 
    end 

    assign M_ALUResult  = reg_ALUResultM;
    assign M_WriteData  = reg_WriteDataM;
    assign M_ImmExt     = reg_ImmExtM;
    assign M_PCPlus4    = reg_PCPlus4M;
    assign M_PCTarget   = reg_PCTargetM;
    assign M_Rd         = reg_M_rd;
    assign M_RegWrite   = reg_RegWriteM;
    assign M_MemWrite   = reg_MemWriteM;
    assign M_ResultSrc  = reg_ResultSrcM;
endmodule