`timescale 1ns/1ps

module HazardUnit #(
    parameter DATA_WIDTH = 32
)(
    input M_RegWrite, W_RegWrite, E_PCSrc, E_MulDivStall, E_FPUStall, W_MDU_FPUEn,
    input M_FRegWrite, W_FRegWrite, E_RegSrc1, E_RegSrc2,
    input [2:0] E_ResultSrc,
    input [4:0] D_Rs1, D_Rs2, E_Rs1, E_Rs2, E_RsF3, E_rd, M_Rd, W_Rd,
    // ATOMIC: Add atomic operation signals
    input E_AtomicOp, E_atomic_done,
    
    output reg [1:0] ForwardAE, ForwardBE, ForwardFCE,
    output F_Stall, D_Stall, E_Stall, D_Flush, E_Flush
);

    // ATOMIC: Hazard logic for atomic operations
    // Block pipeline when atomic is busy and not yet done
    wire atomic_stall;
    assign atomic_stall = E_AtomicOp & ~E_atomic_done;
    
    // Solve Data Hazard
    always @(*) begin
        // ===== ATOMIC: Block reorder with LR/SC/AMO aq/rl =====
        // For now: simple stall when atomic_stall is high
        // (Future: add aq/rl logic to selectively block load/store reordering)
        
        if ((E_Rs1 == M_Rd) & (E_Rs1 != 5'd0)) begin // Forward tu Memory stage
            if ((M_RegWrite & (~E_RegSrc1)) | (M_FRegWrite & E_RegSrc1)) begin
                ForwardAE = 2'b10;
            end
            else begin
                ForwardAE = 2'b00;
            end
        end
        else if ((E_Rs1 == W_Rd) & (E_Rs1 != 5'd0)) begin // Forward tu Writeback stage
            if ((W_RegWrite & (~E_RegSrc1)) | (W_FRegWrite & E_RegSrc1)) begin
                ForwardAE = 2'b01;
            end
            else begin
                ForwardAE = 2'b00;
            end
        end
        else begin
            ForwardAE = 2'b00; // Khong forwarding (dung RF output)
        end
        
        if ((E_Rs2 == M_Rd) & (E_Rs2 != 5'd0)) begin
            if ((M_RegWrite & (~E_RegSrc2)) | (M_FRegWrite & E_RegSrc2)) begin
                ForwardBE = 2'b10;
            end
            else begin
                ForwardBE = 2'b00;
            end
        end
        else if ((E_Rs2 == W_Rd) & (E_Rs2 != 5'd0)) begin
            if ((W_RegWrite & (~E_RegSrc2)) | (W_FRegWrite & E_RegSrc2)) begin
                ForwardBE = 2'b01;
            end
            else begin
                ForwardBE = 2'b00;
            end
        end
        else begin
            ForwardBE = 2'b00;
        end
        
        if ((E_RsF3 == M_Rd) & (E_RsF3 != 5'd0)) begin
            if (M_FRegWrite) begin
                ForwardFCE = 2'b10;
            end
            else begin
                ForwardFCE = 2'b00;
            end
        end
        else if ((E_RsF3 == W_Rd) & (E_RsF3 != 5'd0)) begin
            if (W_FRegWrite) begin
                ForwardFCE = 2'b01;
            end
            else begin
                ForwardFCE = 2'b00;
            end
        end
        else begin
            ForwardFCE = 2'b00;
        end
    end
    
    // ATOMIC: Stall logic
    // Pipeline stalls when:
    // 1. E_MulDivStall is high (MDU/FPU in progress)
    // 2. atomic_stall is high (Atomic unit busy)
    // 3. Load-use hazard
    wire load_use_hazard = ((E_ResultSrc[1:0] == 2'b01) & 
                             ((D_Rs1 == E_rd & D_Rs1 != 5'd0) | 
                              (D_Rs2 == E_rd & D_Rs2 != 5'd0)));
    
    assign D_Stall = load_use_hazard | E_MulDivStall | E_FPUStall | atomic_stall;
    assign E_Stall = E_MulDivStall | E_FPUStall | atomic_stall;  // ATOMIC: Add atomic stall
    assign F_Stall = D_Stall;
    
    assign D_Flush = E_PCSrc;
    assign E_Flush = E_PCSrc;
endmodule
