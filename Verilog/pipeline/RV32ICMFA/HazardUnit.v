`timescale 1ns/1ps

module HazardUnit #(
parameter DATA_WIDTH = 32
)(
input M_RegWrite, W_RegWrite, E_PCSrc, E_MulDivStall, E_FPUStall, W_MDU_FPUEn,
M_FRegWrite, W_FRegWrite, E_RegSrc1, E_RegSrc2,
input [2:0] E_ResultSrc,
input [4:0] D_Rs1, D_Rs2, E_Rs1, E_Rs2, E_RsF3, E_rd, M_Rd, W_Rd,

// ATOMIC: Add atomic stall inputs
input E_AtomicOp,
input E_atomic_done,

output reg [1:0] ForwardAE, ForwardBE, ForwardFCE,
output F_Stall, D_Stall, E_Stall, D_Flush, E_Flush
);

// Solve Data Hazard
always @(*) begin
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

// ATOMIC: Add atomic stall when atomic operation is executing
wire atomic_Stall;
assign atomic_Stall = E_AtomicOp & (~E_atomic_done);

// ATOMIC: Combine all stalls including atomic
assign E_Stall = E_MulDivStall | E_FPUStall | atomic_Stall;
assign F_Stall = lw_Stall | E_Stall;
assign D_Stall = lw_Stall | E_Stall;

// flush khi nhanh duoc lay hoac khi lenh lw duoc thuc thi tao load hazard
assign E_Flush = lw_Stall | E_PCSrc;
assign D_Flush = E_PCSrc;

endmodule
