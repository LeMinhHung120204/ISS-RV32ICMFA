module SignExt(
    input       [24:0] Imm, 
    input       [3:0]  ImmSrcD,
    output reg  [31:0] ImmExtD 
);
    always @(*) begin
        case (ImmSrcD)
            // === RV32I ===
            4'b0000: ImmExtD = {{20{Imm[24]}}, Imm[24:13]};                                       // I-type
            4'b0001: ImmExtD = {{20{Imm[24]}}, Imm[24:18], Imm[4:0]};                             // S-type
            4'b0010: ImmExtD = {{20{Imm[24]}}, Imm[0], Imm[23:18], Imm[4:1], 1'b0};               // B-type
            4'b0011: ImmExtD = {{12{Imm[24]}}, Imm[12:5], Imm[13], Imm[23:14], 1'b0};             // J-type
            4'b0100: ImmExtD = {Imm[24:5], 12'b0};                                                // U-type

            // === Compressed ===
            4'b1000: ImmExtD = {{26{Imm[17]}}, Imm[17:13]};                                       // C.ADDI/C.LI: 6-bit sign-extended
            4'b1001: ImmExtD = {{20{1'b0}}, Imm[12:5], 2'b00};                                    // C.LW/C.SW: offset
            4'b1010: ImmExtD = {{22{1'b0}}, Imm[4:2], Imm[12:10], 2'b00};                         // C.ADDI4SPN: zero-extended
            4'b1011: ImmExtD = {{23{Imm[12]}}, Imm[12], Imm[6:5], Imm[2], Imm[11:10], Imm[4:3], 1'b0}; // C.BEQZ/C.BNEZ: sign-extended branch offset
            4'b1100: ImmExtD = {{15{Imm[17]}}, Imm[17:13], 12'b0};                                // C.LUI (C.LUI rd ≠ x2 && rd ≠ x0)

            // Default (undefined)
            default: ImmExtD = 32'dx;

        endcase
    end
endmodule 