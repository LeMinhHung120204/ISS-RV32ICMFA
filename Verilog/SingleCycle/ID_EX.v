`timescale 1ns/1ps
module ID_EX #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] RD1, RD2, ImmExtD
    input [ADDR_WIDTH - 1:0] PCD, PCPlus4D,
    input RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD,
    input [1:0] ResultSrcD, ImmSrcD,
    input [2:0] ALUControlD,
    output [DATA_WIDTH - 1:0] RD1E, RD2E, ImmExtE,
    output [ADDR_WIDTH - 1:0] PCE, PCPlus4E,
    output RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE,
    output [1:0] ResultSrcE, ImmSrcE,
    output [2:0] ALUControlE,
);

    reg [DATA_WIDTH - 1:0] reg_RD1, reg_RD2, reg_ImmExtE;
    reg [ADDR_WIDTH - 1:0] reg_PCE, reg_PCPlus4E;
    reg reg_RegWriteE, reg_MemWriteE, reg_JumpE, reg_BranchE, reg_ALUSrcE,
    reg [1:0] reg_ResultSrcE, reg_ImmSrcE,
    reg [2:0] reg_ALUControlE,

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_RD1         <= 32'd0;
            reg_RD2         <= 32'd0;
            reg_ImmExtE     <= 32'd0;
            reg_PCE         <= 32'd0;
            reg_PCPlus4E    <= 32'd0;

            reg_RegWriteE   <= 1'b0;
            reg_MemWriteE   <= 1'b0;
            reg_JumpE       <= 1'b0;
            reg_BranchE     <= 1'b0;
            reg_ALUSrcE     <= 1'b0;
            reg_ResultSrcE  <= 2'b0;
            reg_ImmSrcE     <= 2'b0;
            reg_ALUControlE <= 3'b0;

        end 
        else begin
            reg_RD1         <= RD1;
            reg_RD2         <= RD2;
            reg_ImmExtE     <= ImmExtD;
            reg_PCE         <= PCD;
            reg_PCPlus4E    <= PCPlus4D;

            reg_RegWriteE   <= RegWriteD;
            reg_MemWriteE   <= MemWriteD;
            reg_JumpE       <= JumpD;
            reg_BranchE     <= BranchD;
            reg_ALUSrcE     <= ALUSrcD;
            reg_ResultSrcE  <= ResultSrcD;
            reg_ImmSrcE     <= ImmSrcD;
            reg_ALUControlE <= ALUControlD;
        end
    end 

    assign RD1E         = reg_RD1;
    assign RD2E         = reg_RD2;
    assign ImmExtE      = reg_ImmExtE;
    assign PCE          = reg_PCE;
    assign PCPlus4E     = reg_PCPlus4E
    assign RegWriteE    = reg_RegWriteE;
    assign MemWriteE    = reg_MemWriteE;
    assign JumpE        = reg_JumpE;
    assign BranchE      = reg_BranchE;
    assign ALUSrcE      = reg_ALUSrcE;
    assign ResultSrcE   = reg_ResultSrcE;
    assign ImmSrcE      = reg_ImmSrcE;
    assign ALUControlE  = reg_ALUControlE;

endmodule   