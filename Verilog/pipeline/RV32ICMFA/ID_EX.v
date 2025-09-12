`timescale 1ns/1ps
module ID_EX #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n, E_Flush, D_RegWrite, D_MemWrite, D_Jump, D_Branch, D_ALUSrc,
    input [DATA_WIDTH - 1:0]    RD1, RD2, D_ImmExt,
    input [ADDR_WIDTH - 1:0]    D_PC, D_PCPlus4,
    input [2:0]                 D_ResultSrc,
    input [2:0]                 D_funct3,
    input [3:0]                 D_ALUControl,
    input [4:0]                 D_Rs1, D_Rs2, D_Rd,

    output E_RegWrite, E_MemWrite, E_Jump, E_Branch, E_ALUSrc,
    output [DATA_WIDTH - 1:0]   E_RD1, E_RD2, E_ImmExt,
    output [ADDR_WIDTH - 1:0]   E_PC, E_PCPlus4,
    output [2:0]                E_ResultSrc, 
    output [2:0]                E_funct3,
    output [3:0]                E_ALUControl,
    output [4:0]                E_Rs1, E_Rs2, E_Rd
);

    reg reg_RegWriteE, reg_MemWriteE, reg_JumpE, reg_BranchE, reg_ALUSrcE;
    reg [DATA_WIDTH - 1:0] reg_RD1, reg_RD2, reg_ImmExtE;
    reg [ADDR_WIDTH - 1:0] reg_PCE, reg_PCPlus4E;
    reg [2:0] reg_ResultSrcE;
    reg [2:0] reg_funct3E;
    reg [3:0] reg_ALUControlE;
    reg [4:0] reg_RS1, reg_RS2, reg_E_rd;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_RD1         <= 32'd0;
            reg_RD2         <= 32'd0;
            reg_RS1         <= 5'd0;
            reg_RS2         <= 5'd0;
            reg_E_rd        <= 5'd0;
            reg_ImmExtE     <= 32'd0;
            reg_PCE         <= 32'd0;
            reg_PCPlus4E    <= 32'd0;

            reg_RegWriteE   <= 1'b0;
            reg_MemWriteE   <= 1'b0;
            reg_JumpE       <= 1'b0;
            reg_BranchE     <= 1'b0;
            reg_ALUSrcE     <= 1'b0;
            reg_ResultSrcE  <= 3'b0;
            reg_funct3E     <= 3'b0;
            reg_ALUControlE <= 4'b0;

        end 
        else begin
            if (E_Flush) begin
                reg_RD1         <= 32'd0;
                reg_RD2         <= 32'd0;
                reg_RS1         <= 5'd0;
                reg_RS2         <= 5'd0;
                reg_E_rd        <= 5'd0;
                reg_ImmExtE     <= 32'd0;
                reg_PCE         <= 32'd0;
                reg_PCPlus4E    <= 32'd0;

                reg_RegWriteE   <= 1'b0;
                reg_MemWriteE   <= 1'b0;
                reg_JumpE       <= 1'b0;
                reg_BranchE     <= 1'b0;
                reg_ALUSrcE     <= 1'b0;
                reg_ResultSrcE  <= 3'b0;
                reg_funct3E     <= 3'b0;
                reg_ALUControlE <= 4'b0;
            end 
            else begin
                reg_RD1         <= RD1;
                reg_RD2         <= RD2;
                reg_RS1         <= D_Rs1;
                reg_RS2         <= D_Rs2;
                reg_E_rd        <= D_Rd;
                reg_ImmExtE     <= D_ImmExt;
                reg_PCE         <= D_PC;
                reg_PCPlus4E    <= D_PCPlus4;

                reg_RegWriteE   <= D_RegWrite;
                reg_MemWriteE   <= D_MemWrite;
                reg_JumpE       <= D_Jump;
                reg_BranchE     <= D_Branch;
                reg_ALUSrcE     <= D_ALUSrc;
                reg_ResultSrcE  <= D_ResultSrc;
                reg_funct3E     <= D_funct3;
                reg_ALUControlE <= D_ALUControl;
            end 
            
        end
    end 

    assign E_RD1        = reg_RD1;
    assign E_RD2        = reg_RD2;
    assign E_Rs1        = reg_RS1;
    assign E_Rs2        = reg_RS2;
    assign E_Rd         = reg_E_rd;
    assign E_ImmExt     = reg_ImmExtE;
    assign E_PC         = reg_PCE;
    assign E_PCPlus4    = reg_PCPlus4E;
    assign E_RegWrite   = reg_RegWriteE;
    assign E_MemWrite   = reg_MemWriteE;
    assign E_Jump       = reg_JumpE;
    assign E_Branch     = reg_BranchE;
    assign E_ALUSrc     = reg_ALUSrcE;
    assign E_ResultSrc  = reg_ResultSrcE;
    assign E_funct3     = reg_funct3E;
    assign E_ALUControl = reg_ALUControlE;

endmodule   