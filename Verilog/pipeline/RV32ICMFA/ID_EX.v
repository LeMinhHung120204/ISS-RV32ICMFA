`timescale 1ns/1ps
module ID_EX #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input   clk, rst_n, E_Flush, EN,
    input   D_RegWrite, D_MemWrite, D_Jump, D_Branch, D_ALUSrc,
            D_is_high, D_addr_addend_sel, D_ResPCSel, D_valid_MDU, D_FRegWrite, D_Valid_FPU, D_RegSrc1,
    input   [DATA_WIDTH - 1:0]  D_RD1, D_RD2, D_RDF2, D_ImmExt, D_RD3,
    input   [ADDR_WIDTH - 1:0]  D_PC, D_PCPlus4,
    input   [1:0]               D_Mul_Div_unsigned, D_MulDivControl, D_ResExSel,
    input   [2:0]               D_ResultSrc, D_StoreSrc, D_funct3,
    input   [3:0]               D_ALUControl,
    input   [4:0]               D_Rs1, D_Rs2, D_rd, D_RsF3, D_FPUControl,

    output reg  E_RegWrite, E_MemWrite, E_Jump, E_Branch, E_ALUSrc,
                E_is_high, E_addr_addend_sel, E_ResPCSel, E_valid_MDU, E_FRegWrite, E_Valid_FPU, E_RegSrc1,
    output reg  [DATA_WIDTH - 1:0]  E_RD1, E_RD2, E_RDF2, E_ImmExt, E_RD3,
    output reg  [ADDR_WIDTH - 1:0]  E_PC, E_PCPlus4,
    output reg  [1:0]               E_Mul_Div_unsigned, E_MulDivControl, E_ResExSel,
    output reg  [2:0]               E_ResultSrc, E_StoreSrc, E_funct3,
    output reg  [3:0]               E_ALUControl,
    output reg  [4:0]               E_Rs1, E_Rs2, E_rd, E_RsF3, E_FPUControl
);
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            E_RD1               <= 32'd0;
            E_RD2               <= 32'd0;
            E_RDF2              <= 32'd0;
            E_RD3               <= 32'd0;
            E_ImmExt            <= 32'd0;
            E_PC                <= 32'd0;
            E_PCPlus4           <= 32'd0;
            E_Rs1               <= 5'd0;
            E_Rs2               <= 5'd0;
            E_rd                <= 5'd0;
            E_RsF3              <= 5'd0;
            E_FPUControl        <= 5'd0;
            E_ALUControl        <= 4'd0;
            E_StoreSrc          <= 3'd0;
            E_ResultSrc         <= 3'd0;
            E_funct3            <= 3'd0;
            E_Mul_Div_unsigned  <= 2'd0;
            E_MulDivControl     <= 2'd0;
            E_ResExSel          <= 2'd0;
            E_RegWrite          <= 1'd0;
            E_MemWrite          <= 1'd0;
            E_Jump              <= 1'd0;
            E_Branch            <= 1'd0;
            E_ALUSrc            <= 1'd0;
            E_is_high           <= 1'd0;
            E_addr_addend_sel   <= 1'd0;
            E_ResPCSel          <= 1'd0;
            E_valid_MDU         <= 1'd0;
            E_FRegWrite         <= 1'd0;
            E_Valid_FPU         <= 1'd0;
            E_RegSrc1           <= 1'd0;
        end 
        else begin
            if (E_Flush) begin
                E_RD1               <= 32'd0;
                E_RD2               <= 32'd0;
                E_RDF2              <= 32'd0;
                E_RD3               <= 32'd0;
                E_ImmExt            <= 32'd0;
                E_PC                <= 32'd0;
                E_PCPlus4           <= 32'd0;
                E_Rs1               <= 5'd0;
                E_Rs2               <= 5'd0;
                E_rd                <= 5'd0;
                E_RsF3              <= 5'd0;
                E_FPUControl        <= 5'd0;
                E_ALUControl        <= 4'd0;
                E_StoreSrc          <= 3'd0;
                E_ResultSrc         <= 3'd0;
                E_funct3            <= 3'd0;
                E_Mul_Div_unsigned  <= 2'd0;
                E_MulDivControl     <= 2'd0;
                E_ResExSel          <= 2'd0;
                E_RegWrite          <= 1'd0;
                E_MemWrite          <= 1'd0;
                E_Jump              <= 1'd0;
                E_Branch            <= 1'd0;
                E_ALUSrc            <= 1'd0;
                E_is_high           <= 1'd0;
                E_addr_addend_sel   <= 1'd0;
                E_ResPCSel          <= 1'd0;
                E_valid_MDU         <= 1'd0;
                E_FRegWrite         <= 1'd0;
                E_Valid_FPU         <= 1'd0;
                E_RegSrc1           <= 1'd0;
            end 
            else begin 
                if (~EN) begin
                    E_valid_MDU         <= D_valid_MDU;
                    E_Valid_FPU         <= D_Valid_FPU;
                    E_RD1               <= D_RD1             ;
                    E_RD2               <= D_RD2             ;
                    E_RDF2              <= D_RDF2            ;
                    E_RD3               <= D_RD3;
                    E_ImmExt            <= D_ImmExt          ;
                    E_PC                <= D_PC              ;
                    E_PCPlus4           <= D_PCPlus4         ;
                    E_Rs1               <= D_Rs1             ;
                    E_Rs2               <= D_Rs2             ;
                    E_rd                <= D_rd              ;
                    E_RsF3              <= D_RsF3            ;
                    E_FPUControl        <= D_FPUControl      ;
                    E_ALUControl        <= D_ALUControl      ;
                    E_StoreSrc          <= D_StoreSrc        ;
                    E_ResultSrc         <= D_ResultSrc       ;
                    E_funct3            <= D_funct3;
                    E_Mul_Div_unsigned  <= D_Mul_Div_unsigned;
                    E_MulDivControl     <= D_MulDivControl   ;
                    E_ResExSel          <= D_ResExSel        ;
                    E_RegWrite          <= D_RegWrite        ;
                    E_MemWrite          <= D_MemWrite        ;
                    E_Jump              <= D_Jump            ;
                    E_Branch            <= D_Branch          ;
                    E_ALUSrc            <= D_ALUSrc          ;
                    E_is_high           <= D_is_high         ;
                    E_addr_addend_sel   <= D_addr_addend_sel ;
                    E_ResPCSel          <= D_ResPCSel        ;
                    E_FRegWrite         <= D_FRegWrite       ;
                    E_RegSrc1           <= D_RegSrc1         ;
                end 
            end
        end
    end 

endmodule   