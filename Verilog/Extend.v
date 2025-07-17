module SignExt(
    input       [24:0] Imm, 
    input       [3:0]  ImmSrcD,
    output reg  [31:0] ImmExtD 
);
    always @(*) begin
        case (ImmSrcD)
            // === RV32I ===
            4'b0000: ImmExtD = {{20{Imm[24]}}, Imm[24:13]};                            // I-type
            4'b0001: ImmExtD = {{20{Imm[24]}}, Imm[24:18], Imm[4:0]};                  // S-type
            4'b0010: ImmExtD = {{20{Imm[24]}}, Imm[0], Imm[23:18], Imm[4:1], 1'b0};    // B-type
            4'b0011: ImmExtD = {{12{Imm[24]}}, Imm[12:5], Imm[13], Imm[23:14], 1'b0};  // J-type
            4'b0100: ImmExtD = {Imm[24:5], 12'b0};                                     // U-type

            // === Compressed ===
            // truyền {11{0},[15:2]} vào input Imm 
            4'b1000: ImmExtD = {{27{Imm[10]}}, Imm[4:0]};                // CI-type
            4'b1001: ImmExtD = {{27{1'b0}}, Imm[10:8], Imm[4:3]};        // CL/CS-type
            4'b1010: ImmExtD = {{24{1'b0}}, Imm[10:3]};                  // CIW-type
            4'b1011: ImmExtD = {{24{Imm[10]}}, Imm[10:8], Imm[4:0]};     // CB-type
            4'b1100: ImmExtD = {{26{1'b0}}, Imm[10:5]};                  // CSS-type
            default: ImmExtD = 32'dx;
        endcase
    end
endmodule 