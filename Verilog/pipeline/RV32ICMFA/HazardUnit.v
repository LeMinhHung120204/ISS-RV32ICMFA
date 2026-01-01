`timescale 1ns/1ps

module HazardUnit #(
    parameter DATA_WIDTH = 32
)(
    // input       E_PCSrc, 
    input       E_MulDivStall, 
    input       E_FPUStall, 
    input       E_RegSrc1, 
    input       E_RegSrc2, 
    input       E_Mispredict,
    input       M_FRegWrite, 
    input       M_RegWrite, 
    input       C_RegWrite,
    input       C_FRegWrite,
    input       W_FRegWrite, 
    input       W_MDU_FPUEn,
    input       W_RegWrite, 
    
    input       icache_stall,
    input       dcache_stall,
    input [2:0] E_ResultSrc,
    input [4:0] D_Rs1, 
    input [4:0] D_Rs2, 
    input [4:0] E_Rs1, 
    input [4:0] E_Rs2, 
    input [4:0] E_RsF3, 
    input [4:0] E_rd, 
    input [4:0] M_Rd,
    input [4:0] C_Rd, 
    input [4:0] W_Rd,

    output reg [1:0]    ForwardAE, 
    output reg [1:0]    ForwardBE, 
    output reg [1:0]    ForwardFCE,
    output              F_Stall, 
    output              D_Stall, 
    output              E_Stall, 
    output              D_Flush, 
    output              fetch_pipe_Flush,
    output              E_Flush
);

// Solve Data Hazard
    always @(*) begin
        if ((E_Rs1 == M_Rd) && (E_Rs1 != 0) && ((M_RegWrite & ~E_RegSrc1) | (M_FRegWrite & E_RegSrc1)))
            ForwardAE = 2'b01;
        else if ((E_Rs1 == C_Rd) && (E_Rs1 != 0) && ((C_RegWrite & ~E_RegSrc1) | (C_FRegWrite & E_RegSrc1)))
            ForwardAE = 2'b10;
        else if ((E_Rs1 == W_Rd) && (E_Rs1 != 0) && ((W_RegWrite & ~E_RegSrc1) | (W_FRegWrite & E_RegSrc1)))
            ForwardAE = 2'b11;
        else
            ForwardAE = 2'b00;

        if ((E_Rs2 == M_Rd) && (E_Rs2 != 0) && ((M_RegWrite & ~E_RegSrc2) | (M_FRegWrite & E_RegSrc2)))
            ForwardBE = 2'b01;
        else if ((E_Rs2 == C_Rd) && (E_Rs2 != 0) && ((C_RegWrite & ~E_RegSrc2) | (C_FRegWrite & E_RegSrc2)))
            ForwardBE = 2'b10;
        else if ((E_Rs2 == W_Rd) && (E_Rs2 != 0) && ((W_RegWrite & ~E_RegSrc2) | (W_FRegWrite & E_RegSrc2)))
            ForwardBE = 2'b11;
        else
            ForwardBE = 2'b00;
    end

    always @(*) begin
        if ((E_RsF3 == M_Rd) & M_FRegWrite & (E_RsF3 != 5'd0)) begin
            ForwardFCE = 2'b10;
        end
        else if ((E_RsF3 == W_Rd) & W_FRegWrite & (E_RsF3 != 5'd0)) begin
            ForwardFCE = 2'b01;
        end
        else begin
            ForwardFCE = 2'b00;
        end
    end

    // Stall when a load hazard
    wire lw_Stall;
    assign lw_Stall = ((E_ResultSrc == 3'd1) & ((D_Rs1 == E_rd) | (D_Rs2 == E_rd)));

    assign E_Stall = dcache_stall | E_MulDivStall | E_FPUStall;
    assign F_Stall = dcache_stall | icache_stall | lw_Stall | E_Stall;
    assign D_Stall = dcache_stall | lw_Stall | E_Stall;

    // flush khi nhanh duoc lay hoac khi lenh lw duoc thuc thi tao load hazard
    // assign E_Flush = lw_Stall | E_PCSrc | E_Mispredict;
    // assign D_Flush = E_PCSrc | E_Mispredict;
    assign E_Flush          = lw_Stall | E_Mispredict;
    assign D_Flush          = E_Mispredict;
    assign fetch_pipe_Flush = E_Mispredict;
endmodule
