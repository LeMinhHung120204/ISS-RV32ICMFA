`timescale 1ns/1ps

module atomic_decoder_tb;

    reg [31:0] instr;
    wire is_atomic;
    wire [4:0] funct5;
    wire aq;
    wire rl;
    wire [2:0] funct3;

    // Instantiate the decoder
    atomic_decoder dut (
        .instr(instr),
        .is_atomic(is_atomic),
        .funct5(funct5),
        .aq(aq),
        .rl(rl),
        .funct3(funct3)
    );

    initial begin
        $display("=== ATOMIC DECODER TEST START ===");

        // Test 1: Valid Atomic Instruction (LR.W)
        // Opcode = 0101111 (0x2F)
        // Funct3 = 010 (Word)
        // Funct5 = 00010 (LR)
        // aq=0, rl=0
        // Binary: 00010 00 00000 00000 010 00000 0101111
        // Hex: 0x1000202F
        instr = 32'h1000202F;
        #1;
        if (is_atomic === 1'b1 && funct3 === 3'b010 && funct5 === 5'b00010)
            $display("PASS: Valid LR.W detected");
        else
            $display("FAIL: Valid LR.W NOT detected correctly. is_atomic=%b, funct3=%b", is_atomic, funct3);

        // Test 2: Invalid Funct3 (Byte width - not supported in RV32A standard for LR/SC usually, but here testing decoder strictness)
        // Same as above but funct3 = 000
        // Binary: 00010 00 00000 00000 000 00000 0101111
        // Hex: 0x1000002F
        instr = 32'h1000002F;
        #1;
        if (is_atomic === 1'b0)
            $display("PASS: Invalid Funct3 (000) ignored");
        else
            $display("FAIL: Invalid Funct3 (000) was ACCEPTED as atomic");

        // Test 3: Non-Atomic Opcode
        // Opcode = 0110011 (OP - ADD)
        instr = 32'h00000033;
        #1;
        if (is_atomic === 1'b0)
            $display("PASS: Non-atomic opcode ignored");
        else
            $display("FAIL: Non-atomic opcode accepted");

        $display("=== ATOMIC DECODER TEST COMPLETE ===");
        $finish;
    end

endmodule
