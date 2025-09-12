`timescale 1ns/1ps
module BranchDecoder(
    input E_Jump, E_Zero, E_Branch, E_signed_less,
    input [2:0] funct3,
    output E_PCSrc
);
    reg E_con;
    always @(*) begin
        case(funct3)
            3'b000: begin   // beq
                E_con = E_Zero;
            end 
            3'b001: begin   // bne
                E_con = ~E_Zero;
            end 
            3'b100, 3'b110: begin       // blt, bltu,
                E_con = E_signed_less;
            end 
            3'b101, 3'b111: begin
                E_con = ~E_signed_less; // bge, begu
            end 
            default: begin
                E_con = E_Zero;
            end 
        endcase
    end

    assign E_PCSrc = E_Jump | (E_con & E_Branch);
endmodule