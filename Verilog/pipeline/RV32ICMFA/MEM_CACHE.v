`timescale 1ns/1ps
// from Lee Min Hunz with luv
// ============================================================================
// MEM_CACHE Pipeline Register
// ============================================================================
// Pipeline stage: Memory (MEM) -> Cache Wait (C)
//
// Function:
//   - Holds ALU result and control signals while waiting for dcache
//   - Enables forwarding from cache stage to earlier stages  
//   - Stalls when dcache is busy (EN=1 holds values)
//
// Note: This stage allows the pipeline to tolerate dcache latency
//       without stalling the entire pipeline on every memory access.
// ============================================================================
module MEM_CACHE #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input                       clk, rst_n
,   input                       EN 
,   input                       M_RegWrite 
// ,   input                       M_FRegWrite 
// ,   input                       M_MDU_FPUEn
,   input [DATA_WIDTH - 1:0]    M_Result 
    // input [DATA_WIDTH - 1:0]    M_ReadData, 
// ,   input [DATA_WIDTH - 1:0]    M_ImmExt
// ,   input [ADDR_WIDTH - 1:0]    M_ResPC
,   input [4:0]                 M_rd
,   input [2:0]                 M_ResultSrc
    
,   output reg                      C_RegWrite 
// ,   output reg                      C_FRegWrite 
// ,   output reg                      C_MDU_FPUEn
,   output reg [DATA_WIDTH - 1:0]   C_Result 
    // output reg [DATA_WIDTH - 1:0]   C_ReadData, 
// ,   output reg [DATA_WIDTH - 1:0]   C_ImmExt
// ,   output reg [ADDR_WIDTH - 1:0]   C_ResPC
,   output reg [4:0]                C_rd
,   output reg [2:0]                C_ResultSrc
    
);
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            C_Result    <= 32'd0; 
            // C_ReadData  <= 32'd0;
            // C_ImmExt    <= 32'd0;
            // C_ResPC     <= 32'd0;
            C_rd        <= 5'd0;
            C_ResultSrc <= 3'b0;
            C_RegWrite  <= 1'b0;
            // C_FRegWrite <= 1'b0;
            // C_MDU_FPUEn <= 1'b0;
        end 
        else if (~EN) begin
            C_Result    <= M_Result   ; 
            // C_ReadData  <= M_ReadData;
            // C_ImmExt    <= M_ImmExt   ;
            // C_ResPC     <= M_ResPC    ;
            C_rd        <= M_rd       ;
            C_ResultSrc <= M_ResultSrc;
            C_RegWrite  <= M_RegWrite ;
            // C_FRegWrite <= M_FRegWrite;
            // C_MDU_FPUEn <= M_MDU_FPUEn;
        end 
    end 
endmodule
