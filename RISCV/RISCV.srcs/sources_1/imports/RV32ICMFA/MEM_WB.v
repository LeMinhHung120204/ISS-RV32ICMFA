`timescale 1ns/1ps

module MEM_WB #(
    parameter WIDTH_DATA = 32
)(
    input clk, rst_n,
    
    // From EX_MEM
    input [WIDTH_DATA-1:0] M_Result, M_ReadData, M_ImmExt, M_ResPC,
    input [4:0] M_rd,
    input M_RegWrite, M_FRegWrite,
    input [2:0] M_ResultSrc,
    input M_MDU_FPUEn,
    // ATOMIC: Add atomic signals
    input M_AtomicOp,
    input [WIDTH_DATA-1:0] M_atomic_rdata,
    
    // To Writeback (Output)
    output reg [WIDTH_DATA-1:0] W_Result, W_ReadData, W_ImmExt, W_ResPC,
    output reg [4:0] W_rd,
    output reg W_RegWrite, W_FRegWrite,
    output reg [2:0] W_ResultSrc,
    output reg W_MDU_FPUEn
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            W_Result   <= 0;
            W_ReadData <= 0;
            W_ImmExt   <= 0;
            W_ResPC    <= 0;
            W_rd       <= 0;
            W_RegWrite <= 0;
            W_FRegWrite <= 0;
            W_ResultSrc <= 0;
            W_MDU_FPUEn <= 0;
        end else begin
            // ATOMIC: Route atomic result to W_Result
            W_Result   <= (M_AtomicOp) ? M_atomic_rdata : M_Result;
            W_ReadData <= M_ReadData;
            W_ImmExt   <= M_ImmExt;
            W_ResPC    <= M_ResPC;
            W_rd       <= M_rd;
            W_RegWrite <= M_RegWrite;
            W_FRegWrite <= M_FRegWrite;
            W_ResultSrc <= M_ResultSrc;
            W_MDU_FPUEn <= M_MDU_FPUEn;
        end
    end
endmodule
