`timescale 1ns/1ps

module ControlUnit(
    input [6:0] op,
    input [14:12] funct3,
    input funct7_5, Zero,
    output MemWrite, ALUSrc, RegWrite, Jump, Branch,
    output [3:0] ALUControl,
    output [1:0] ImmSrc, ResultSrc
);
    wire [1:0] ALUOp;
    MainDecoder maindecoder_inst(
        .op(op),
        .Branch(Branch),
        .ResultSrc(ResultSrc),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .ImmSrc(ImmSrc),
        .ALUOp(ALUOp),
        .Jump(Jump)
    );

    AluDecoder aludecoder_inst(
        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7_5(funct7_5),
        .op_5(op[5]),
        .ALUControl(ALUControl)
    );
    
endmodule