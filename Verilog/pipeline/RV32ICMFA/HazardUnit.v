`timescale 1ns/1ps
// from Lee Min Hunz with luv

module HazardUnit #(
    parameter DATA_WIDTH = 32
)(
    input       E_MulDivStall 
,   input       E_FPUStall 
,   input       E_RegSrc1 
,   input       E_RegSrc2 
,   input       E_Mispredict
,   input       M_FRegWrite 
,   input       M_RegWrite 
,   input       C_RegWrite
,   input       C_FRegWrite
,   input       W_FRegWrite 
,   input       W_RegWrite 
    
,   input       icache_stall
,   input       dcache_stall

,   input [2:0] E_ResultSrc
,   input [4:0] D_Rs1 
,   input [4:0] D_Rs2 
,   input [4:0] E_Rs1 
,   input [4:0] E_Rs2 
    // input [4:0] E_RsF3, 
,   input [4:0] E_rd 
,   input [4:0] M_Rd
,   input [4:0] C_Rd 
,   input [4:0] W_Rd

,   output reg [1:0]    ForwardAE 
,   output reg [1:0]    ForwardBE 
    // output reg [1:0]    ForwardFCE,
,   output              F_Stall 
,   output              D_Stall 
,   output              E_Stall 
,   output              M_Stall
,   output              D_Flush 
,   output              fetch_pipe_Flush
,   output              E_Flush
);

    // ================================================================
    // FORWARDING MATCH SIGNALS
    // ================================================================
    wire match_M_A  = (E_Rs1 == M_Rd) && (|E_Rs1) && (E_RegSrc1 ? M_FRegWrite : M_RegWrite);
    wire match_C_A  = (E_Rs1 == C_Rd) && (|E_Rs1) && (E_RegSrc1 ? C_FRegWrite : C_RegWrite);
    wire match_W_A  = (E_Rs1 == W_Rd) && (|E_Rs1) && (E_RegSrc1 ? W_FRegWrite : W_RegWrite);

    wire match_M_B  = (E_Rs2 == M_Rd) && (|E_Rs2) && (E_RegSrc2 ? M_FRegWrite : M_RegWrite);
    wire match_C_B  = (E_Rs2 == C_Rd) && (|E_Rs2) && (E_RegSrc2 ? C_FRegWrite : C_RegWrite);
    wire match_W_B  = (E_Rs2 == W_Rd) && (|E_Rs2) && (E_RegSrc2 ? W_FRegWrite : W_RegWrite);

    // wire match_M_F3 = (E_RsF3 == M_Rd) && (|E_RsF3) && M_FRegWrite;
    // wire match_W_F3 = (E_RsF3 == W_Rd) && (|E_RsF3) && W_FRegWrite;

    // ================================================================
    // FORWARDING MUX SELECT LOGIC
    // ================================================================
    always @(*) begin
        // --- Forwarding cho A ---
        casez ({match_M_A, match_C_A, match_W_A})
            3'b1?? : ForwardAE = 2'b01; 
            3'b01? : ForwardAE = 2'b10; 
            3'b001 : ForwardAE = 2'b11; 
            default: ForwardAE = 2'b00; 
        endcase

        // --- Forwarding cho B ---
        casez ({match_M_B, match_C_B, match_W_B})
            3'b1?? : ForwardBE = 2'b01; 
            3'b01? : ForwardBE = 2'b10;
            3'b001 : ForwardBE = 2'b11;
            default: ForwardBE = 2'b00;
        endcase
    end

    // ================================================================
    // STALL & FLUSH LOGIC
    // ================================================================
    // Stall when a load hazard
    wire lw_Stall;
    assign lw_Stall = ((E_ResultSrc == 3'd1) & ((D_Rs1 == E_rd) | (D_Rs2 == E_rd)));

    // assign M_Stall          = dcache_stall ;
    // assign E_Stall          = dcache_stall | E_MulDivStall | E_FPUStall;
    // assign D_Stall          = dcache_stall | lw_Stall | E_Stall;
    // assign F_Stall          = dcache_stall | lw_Stall | E_Stall | icache_stall;
    
    // // flush khi nhanh duoc lay hoac khi lenh lw duoc thuc thi tao load hazard
    // assign E_Flush          = lw_Stall | E_Mispredict;
    // // assign E_Flush          = lw_Stall;
    // assign D_Flush          = E_Mispredict;
    // assign fetch_pipe_Flush = E_Mispredict;

    // 1. D-Cache stalls lock the backend (M, E, D)
    assign M_Stall          = dcache_stall ;
    assign E_Stall          = dcache_stall | E_MulDivStall | E_FPUStall;
    assign D_Stall          = dcache_stall | lw_Stall | E_Stall;

    // 2. F_Stall logic: Mispredict OVERRIDES icache_stall and lw_Stall
    // Nếu EX bị kẹt (E_Stall=1), F_Stall vẫn phải bật để đợi.
    // Nếu EX không kẹt, E_Mispredict sẽ ép F_Stall xuống 0 để PC lọt qua và cập nhật E_Correct_PC.
    assign F_Stall          = E_Stall | ((icache_stall | lw_Stall) & ~E_Mispredict);

    // 3. Flush logic: MUST be masked by Stall!
    // Không bao giờ được flush một tầng đang bị kẹt để bảo toàn state.
    assign E_Flush          = (lw_Stall | E_Mispredict) & ~E_Stall;
    assign D_Flush          = E_Mispredict & ~D_Stall;
    
    // fetch_pipe_Flush cũng được dùng làm icache_flush, nên nó chỉ kích hoạt khi F không bị dcache bắt stall.
    assign fetch_pipe_Flush = E_Mispredict & ~F_Stall;
endmodule
