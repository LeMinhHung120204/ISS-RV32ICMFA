`timescale 1ns/1ps
module HazardUnit #(
    parameter DATA_WIDTH = 32
)(
    input M_RegWrite, W_RegWrite, E_ResultSrc_0, E_PCSrc, 
    input [4:0] D_Rs1, D_Rs2, E_Rs1, E_Rs2, E_Rd, M_Rd, W_Rd,
    output reg [1:0] ForwardAE, ForwardBE,       // forward cho SrcAE, SrcBE
    output F_Stall, D_Stall, D_Flush, E_Flush

);
    // Solve Data Hazard
    always @(*) begin
        if ((E_Rs1 == M_Rd) & M_RegWrite & (E_Rs1 != 5'd0)) begin       //  Forward tu Memory stage
            ForwardAE = 2'b10;
        end 
        else if ((E_Rs1 == W_Rd) & W_RegWrite & (E_Rs1 != 5'd0)) begin  // Forward tu Writeback stage
            ForwardAE = 2'b01;
        end 
        else begin
            ForwardAE = 2'b00;  //  Khong forwarding (dung RF output)
        end 

        if ((E_Rs2 == M_Rd) & M_RegWrite & (E_Rs2 != 5'd0)) begin
            ForwardBE = 2'b10;
        end 
        else if ((E_Rs2 == W_Rd) & W_RegWrite & (E_Rs2 != 5'd0)) begin
            ForwardBE = 2'b01;
        end 
        else begin
            ForwardBE = 2'b00;
        end  
    end 

    // Stall when a load hazard
    wire lw_Stall;
    assign lw_Stall = E_ResultSrc_0 & ((D_Rs1 == E_Rd) | (D_Rs2 == E_Rd));
    assign F_Stall  = lw_Stall;
    assign D_Stall  = lw_Stall;

    // flush khi nhanh duoc lay hoac khi lenh lw duoc thuc thi tao load hazard
    assign E_Flush  = lw_Stall | E_PCSrc;
    assign D_Flush  = E_PCSrc;
endmodule 