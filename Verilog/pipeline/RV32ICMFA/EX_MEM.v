`timescale 1ns/1ps
module EX_MEM #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input   clk, rst_n, E_RegWrite, E_MemWrite, E_FRegWrite, E_ResPCSel, E_MDU_FPUEn,
    input   [DATA_WIDTH - 1:0]  E_ALUResult, E_WriteData, E_ImmExt, E_MDUResult, E_FPUResult,
    input   [ADDR_WIDTH - 1:0]  E_PCPlus4, E_PCTarget,
    input   [4:0]               E_rd,
    input   [2:0]               E_ResultSrc, E_StoreSrc,
    input   [1:0]               E_ResExSel,

    output reg M_RegWrite, M_MemWrite, M_FRegWrite, M_ResPCSel, M_MDU_FPUEn,
    output reg [DATA_WIDTH - 1:0]    M_ALUResult, M_WriteData, M_ImmExt, M_MDUResult, M_FPUResult,
    output reg [ADDR_WIDTH - 1:0]    M_PCPlus4, M_PCTarget,
    output reg [4:0]                 M_rd,
    output reg [2:0]                 M_ResultSrc, M_StoreSrc,
    output reg [1:0]                 M_ResExSel
);
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            M_ALUResult <= 32'd0;
            M_WriteData <= 32'd0;
            M_ImmExt    <= 32'd0;
            M_MDUResult <= 32'd0;
            M_FPUResult <= 32'd0;
            M_PCPlus4   <= 32'd0;
            M_PCTarget  <= 32'd0;
            M_rd        <= 5'd0;
            M_ResultSrc <= 3'd0;
            M_StoreSrc  <= 3'd0;
            M_ResExSel  <= 2'd0;
            M_RegWrite  <= 1'd0;
            M_MemWrite  <= 1'd0;
            M_FRegWrite <= 1'd0;
            M_ResPCSel  <= 1'd0;
            M_MDU_FPUEn <= 1'd0;
        end 
        else begin
            M_ALUResult <= E_ALUResult;
            M_WriteData <= E_WriteData;
            M_ImmExt    <= E_ImmExt   ;
            M_MDUResult <= E_MDUResult;
            M_FPUResult <= E_FPUResult;
            M_PCPlus4   <= E_PCPlus4  ;
            M_PCTarget  <= E_PCTarget ;
            M_rd        <= E_rd       ;
            M_ResultSrc <= E_ResultSrc;
            M_StoreSrc  <= E_StoreSrc ;
            M_ResExSel  <= E_ResExSel ;
            M_RegWrite  <= E_RegWrite ;
            M_MemWrite  <= E_MemWrite ;
            M_FRegWrite <= E_FRegWrite;
            M_ResPCSel  <= E_ResPCSel ;
            M_MDU_FPUEn <= E_MDU_FPUEn;
        end 
    end 
endmodule