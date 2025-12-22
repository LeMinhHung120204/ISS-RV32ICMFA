`timescale 1ns/1ps
module ID_EX #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input   clk, rst_n, 
    input   E_Flush, 
    input   EN,
    input   D_RegWrite, 
    input   D_MemWrite, 
    input   D_Jump, 
    input   D_Branch, 
    input   D_ALUSrc,
    input   D_is_high, 
    input   D_addr_addend_sel, 
    input   D_ResPCSel, 
    input   D_valid_MDU, 
    input   D_FRegWrite, 
    input   D_Valid_FPU, 
    input   D_RegSrc1, 
    input   D_RegSrc2,
    input   D_Predict_Taken,
    input   [DATA_WIDTH - 1:0]  D_RD1, 
    input   [DATA_WIDTH - 1:0]  D_RD2, 
    input   [DATA_WIDTH - 1:0]  D_RDF2, 
    input   [DATA_WIDTH - 1:0]  D_ImmExt, 
    input   [DATA_WIDTH - 1:0]  D_RD3,
    input   [ADDR_WIDTH - 1:0]  D_PC, 
    input   [ADDR_WIDTH - 1:0]  D_PCPlus4,
    input   [1:0]               D_Mul_Div_unsigned, 
    input   [1:0]               D_MulDivControl, 
    input   [1:0]               D_ResExSel,
    input   [2:0]               D_ResultSrc, 
    input   [2:0]               D_StoreSrc, 
    input   [2:0]               D_funct3, 
    input   [2:0]               D_GHSR,
    input   [3:0]               D_ALUControl,
    input   [4:0]               D_Rs1, 
    input   [4:0]               D_Rs2, 
    input   [4:0]               D_rd, 
    input   [4:0]               D_RsF3, 
    input   [4:0]               D_FPUControl,
    
    // // atomic inputs
    // input   D_is_atomic,
    // input   [4:0]  D_atomic_funct5,
    // input   D_atomic_aq,
    // input   D_atomic_rl,
    // input   [2:0]  D_atomic_funct3,

    output reg  E_RegWrite, 
    output reg  E_MemWrite, 
    output reg  E_Jump, 
    output reg  E_Branch, 
    output reg  E_ALUSrc,
    output reg  E_is_high, 
    output reg  E_addr_addend_sel, 
    output reg  E_ResPCSel, 
    output reg  E_valid_MDU, 
    output reg  E_FRegWrite, 
    output reg  E_Valid_FPU, 
    output reg  E_RegSrc1, 
    output reg  E_RegSrc2,
    output reg  E_Predict_Taken,
    output reg  [DATA_WIDTH - 1:0]  E_RD1, 
    output reg  [DATA_WIDTH - 1:0]  E_RD2, 
    output reg  [DATA_WIDTH - 1:0]  E_RDF2, 
    output reg  [DATA_WIDTH - 1:0]  E_ImmExt, 
    output reg  [DATA_WIDTH - 1:0]  E_RD3,
    output reg  [ADDR_WIDTH - 1:0]  E_PC, 
    output reg  [ADDR_WIDTH - 1:0]  E_PCPlus4,
    output reg  [1:0]               E_Mul_Div_unsigned, 
    output reg  [1:0]               E_MulDivControl, 
    output reg  [1:0]               E_ResExSel,
    output reg  [2:0]               E_ResultSrc, 
    output reg  [2:0]               E_StoreSrc, 
    output reg  [2:0]               E_funct3, 
    output reg  [2:0]               E_GHSR,
    output reg  [3:0]               E_ALUControl,
    output reg  [4:0]               E_Rs1, 
    output reg  [4:0]               E_Rs2, 
    output reg  [4:0]               E_rd, 
    output reg  [4:0]               E_RsF3, 
    output reg  [4:0]               E_FPUControl
    
    // atomic outputs
    // output reg E_is_atomic,
    // output reg [4:0]  E_atomic_funct5,
    // output reg E_atomic_aq,
    // output reg E_atomic_rl,
    // output reg [2:0]  E_atomic_funct3
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
            E_GHSR              <= 3'd0;
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
            E_RegSrc2           <= 1'd0;
            E_Predict_Taken     <= 1'b0;
            
            // reset atomic
            // E_is_atomic         <= 1'b0;
            // E_atomic_funct5     <= 5'd0;
            // E_atomic_aq         <= 1'b0;
            // E_atomic_rl         <= 1'b0;
            // E_atomic_funct3     <= 3'd0;
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
                E_GHSR              <= 3'd0;
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
                E_RegSrc2           <= 1'd0;
                E_Predict_Taken     <= 1'b0;
                
                // flush atomic
                // E_is_atomic         <= 1'b0;
                // E_atomic_funct5     <= 5'd0;
                // E_atomic_aq         <= 1'b0;
                // E_atomic_rl         <= 1'b0;
                // E_atomic_funct3     <= 3'd0;
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
                    E_GHSR              <= D_GHSR;
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
                    E_RegSrc2           <= D_RegSrc2         ;
                    E_Predict_Taken     <= D_Predict_Taken   ;
                    
                    // forward atomic
                    // E_is_atomic         <= D_is_atomic;
                    // E_atomic_funct5     <= D_atomic_funct5;
                    // E_atomic_aq         <= D_atomic_aq;
                    // E_atomic_rl         <= D_atomic_rl;
                    // E_atomic_funct3     <= D_atomic_funct3;
                end 
            end
        end
    end 

endmodule
