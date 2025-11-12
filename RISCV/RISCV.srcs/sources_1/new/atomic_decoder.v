`timescale 1ns/1ps

module atomic_decoder (
    input [4:0] atomic_funct5,
    output reg [3:0] atomic_op
);

    // ATOMIC: Decode atomic instruction type from funct5
    always @(*) begin
        case(atomic_funct5)
            5'b00010: atomic_op = 4'b0000;  // LR (Load-Reserved)
            5'b00011: atomic_op = 4'b0001;  // SC (Store-Conditional)
            5'b00001: atomic_op = 4'b0010;  // AMOSWAP
            5'b00000: atomic_op = 4'b0011;  // AMOADD
            5'b00100: atomic_op = 4'b0100;  // AMOXOR
            5'b01100: atomic_op = 4'b0101;  // AMOAND
            5'b01000: atomic_op = 4'b0110;  // AMOOR
            5'b10000: atomic_op = 4'b0111;  // AMOMIN (signed)
            5'b10100: atomic_op = 4'b1000;  // AMOMAX (signed)
            5'b11000: atomic_op = 4'b1001;  // AMOMINU (unsigned)
            5'b11100: atomic_op = 4'b1010;  // AMOMAXU (unsigned)
            default:  atomic_op = 4'b1111;  // Invalid
        endcase
    end

endmodule
