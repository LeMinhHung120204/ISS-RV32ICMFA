`timescale 1ns/1ps
module EX_MEM #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input   clk, rst_n, 
    input   EN,
    input   E_RegWrite, 
    input   E_MemWrite, 
    input   E_FRegWrite, 
    input   E_ResPCSel, 
    input   E_MDU_FPUEn,
    input   E_data_req,
    input   [DATA_WIDTH - 1:0]  E_ALUResult, 
    input   [DATA_WIDTH - 1:0]  E_WriteData, 
    input   [DATA_WIDTH - 1:0]  E_ImmExt, 
    input   [DATA_WIDTH - 1:0]  E_MDUResult, 
    input   [DATA_WIDTH - 1:0]  E_FPUResult,
    input   [ADDR_WIDTH - 1:0]  E_PCPlus4, 
    input   [ADDR_WIDTH - 1:0]  E_PCTarget,
    input   [4:0]               E_rd,
    input   [2:0]               E_ResultSrc, 
    input   [2:0]               E_StoreSrc,
    input   [1:0]               E_ResExSel,

    output reg  M_RegWrite, 
    output reg  M_MemWrite, 
    output reg  M_FRegWrite, 
    output reg  M_ResPCSel, 
    output reg  M_MDU_FPUEn,
    output reg  M_data_req,
    output reg [DATA_WIDTH - 1:0]   M_ALUResult, 
    output reg [DATA_WIDTH - 1:0]   M_WriteData, 
    output reg [DATA_WIDTH - 1:0]   M_ImmExt, 
    output reg [DATA_WIDTH - 1:0]   M_MDUResult, 
    output reg [DATA_WIDTH - 1:0]   M_FPUResult,
    output reg [ADDR_WIDTH - 1:0]   M_PCPlus4, 
    output reg [ADDR_WIDTH - 1:0]   M_PCTarget,
    output reg [4:0]                M_rd,
    output reg [2:0]                M_ResultSrc, 
    output reg [2:0]                M_StoreSrc,
    output reg [1:0]                M_ResExSel
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
            M_data_req  <= 1'b0;
            // M_is_atomic     <= 1'b0;            // atomic
            // M_atomic_rdata  <= 32'd0;
            // M_atomic_done   <= 1'b0;
        end 
        else if (~EN) begin
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
            M_data_req  <= E_data_req;
            // M_is_atomic     <= E_is_atomic;     // atomic
            // M_atomic_rdata  <= E_atomic_rdata;
            // M_atomic_done   <= E_atomic_done;
        end 
    end 
endmodule
