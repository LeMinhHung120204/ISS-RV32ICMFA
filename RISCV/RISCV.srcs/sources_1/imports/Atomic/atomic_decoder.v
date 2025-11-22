`timescale 1ns/1ps

module atomic_decoder(
    input [31:0] instr,
    output reg is_atomic,
    output reg [4:0] funct5,
    output reg aq,
    output reg rl,
    output reg [2:0] funct3
);

    wire [6:0] opcode = instr[6:0];
    wire [6:0] funct7 = instr[31:25];
    
    always @(*) begin
        // Default values
        is_atomic = 1'b0;
        funct5 = 5'b0;
        aq = 1'b0;
        rl = 1'b0;
        funct3 = 3'b0;
        
        // Check if opcode is AMO (0101111) AND funct3 is 010 (Word)
        if (opcode == 7'b0101111 && instr[14:12] == 3'b010) begin
            is_atomic = 1'b1;
            funct5 = funct7[6:2];  // Extract funct5 from funct7[6:2]
            aq = funct7[1];        // Acquire bit
            rl = funct7[0];        // Release bit
            funct3 = instr[14:12]; // Width (010 for .W)
        end
    end

endmodule
