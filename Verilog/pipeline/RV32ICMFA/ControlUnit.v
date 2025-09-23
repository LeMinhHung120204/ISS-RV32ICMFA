`timescale 1ns/1ps
module ControlUnit(
    input   [6:0]   op,
    input   [2:0]   funct3,
    input   [6:0]   funct7,
    output          MemWrite, ALUSrc, RegWrite, Jump, Branch, PCTargetSrc, is_high,
    output  [3:0]   ALUControl,
    output  [2:0]   ImmSrc, ResultSrc, StoreSrc,
    output  [1:0]   Mul_Div_unsigned 
);
    wire [1:0] ALUOp;
    MainDecoder maindecoder_inst(
        .op(op),
        .funct3(funct3),
        .funct7(funct7),
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
        .funct7_5(funct7[5]),
        .op_5(op[5]),
        .ALUControl(ALUControl)
    );

    MulDivDecode MulDivDecode_inst(
        .MulDivOp(funct7[0]),
        .funct3(funct3),
        .Mul_Div_unsigned(Mul_Div_unsigned),
        .is_high(is_high)
    );
    
endmodule