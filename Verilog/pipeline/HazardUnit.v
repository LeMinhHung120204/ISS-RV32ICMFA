`timescale 1ns/1ps
module HazardUnit #(
    parameter DATA_WIDTH = 32
)(
    input M_RegWrite, W_RegWrite,
    input [4:0] E_Rs1, E_Rs2, M_Rd, W_Rd,
    output reg [1:0] ForwardAE, ForwardBE       // forward cho SrcAE, SrcBE
);

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
endmodule 