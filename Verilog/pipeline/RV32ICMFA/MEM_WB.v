`timescale 1ns/1ps
module MEM_WB #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] M_Result, M_ReadData, M_ImmExt,
    input [ADDR_WIDTH - 1:0] M_ResPC,
    input [4:0] M_rd,
    input [2:0] M_ResultSrc,
    input M_RegWrite, M_FRegWrite, M_MDU_FPUEn,
    input [DATA_WIDTH-1:0] M_atomic_rdata,
    output reg [DATA_WIDTH - 1:0] W_Result, W_ReadData, W_ImmExt,
    output reg [ADDR_WIDTH - 1:0] W_ResPC,
    output reg [4:0] W_rd,
    output reg [2:0] W_ResultSrc,
    output reg W_RegWrite, W_FRegWrite, W_MDU_FPUEn
);
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            W_Result    <= 32'd0; 
            W_ReadData  <= 32'd0;
            W_ImmExt    <= 32'd0;
            W_ResPC     <= 32'd0;
            W_rd        <= 5'd0;
            W_ResultSrc <= 3'b0;
            W_RegWrite  <= 1'b0;
            W_FRegWrite <= 1'b0;
            W_MDU_FPUEn <= 1'b0;
        end 
        else begin
            W_Result    <= M_Result   ; 
            W_ReadData  <= M_ReadData;
            W_ImmExt    <= M_ImmExt   ;
            W_ResPC     <= M_ResPC    ;
            W_rd        <= M_rd       ;
            W_ResultSrc <= M_ResultSrc;
            W_RegWrite  <= M_RegWrite ;
            W_FRegWrite <= M_FRegWrite;
            W_MDU_FPUEn <= M_MDU_FPUEn;
        end 
    end 
endmodule
