`timescale 1ns/1ps

module Extend(
    input [1:0] ImmSrc,
    input [31:0] Instr,
    output reg [31:0] ImmExt
);
    always@(*) begin
        case(ImmSrc)
            2'd0: ImmExt = {{20{Instr[31]}}, Instr[31:20]};                                 // I-type 12-bit signed immediate
            2'd1: ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};                    // S-type 12-bit signed immediate
            2'd2: ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};    // B-type 13-bit signed immediate
            2'd3: ImmExt = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0};  // J-type 21-bit signed immediate
        endcase
    end
endmodule