`timescale 1ns/1ps
module ControlUnit(
    input   [6:0]   op,
    input   [2:0]   funct3,
    input           funct7_5, Zero,
    output          MemWrite, ALUSrc, RegWrite, Jump, Branch, PCTargetSrc,
    output  [3:0]   ALUControl,
    output  [2:0]   ImmSrc, ResultSrc, StoreSrc
);
    wire [1:0] ALUOp;
    MainDecoder maindecoder_inst(
        .op(op),
        .funct3(funct3),
        .Branch(Branch),
        .ResultSrc(ResultSrc),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .ImmSrc(ImmSrc),
        .ALUOp(ALUOp),
        .Jump(Jump),
        .PCTargetSrc(PCTargetSrc),
        .StoreSrc(StoreSrc)
    );

    AluDecoder aludecoder_inst(
        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7_5(funct7_5),
        .op_5(op[5]),
        .ALUControl(ALUControl)
    );
    
endmodule