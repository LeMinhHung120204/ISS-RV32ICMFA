`timescale 1ns/1ps
module ControlUnit(
    input   [6:0]   op,
    input   [6:0]   funct7,
    input   [4:0]   funct5,
    input   [2:0]   funct3,
    output          MemWrite, ALUSrc, RegWrite, Jump, Branch, is_high, addr_addend_sel, 
                    ResPCSel, valid_MDU, FRegWrite, Valid_FPU, RegSrc1, RegSrc2,
    output  [4:0]   FPUControl,
    output  [3:0]   ALUControl,
    output  [2:0]   ImmSrc, ResultSrc, StoreSrc,
    output  [1:0]   Mul_Div_unsigned, MulDivControl, ResExSel
);
    wire [1:0] ALUOp;
    wire [2:0] FPUOp;
    MainDecoder maindecoder_inst(
        .op(op),
        .funct3(funct3),
        .funct7(funct7),
        .Branch(Branch),
        .ResultSrc(ResultSrc),
        .MemWrite(MemWrite),
        .RegSrc1(RegSrc1),
        .RegSrc2(RegSrc2),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .FRegWrite(FRegWrite),
        .ImmSrc(ImmSrc),
        .ALUOp(ALUOp),
        .Jump(Jump),
        .StoreSrc(StoreSrc),
        .addr_addend_sel(addr_addend_sel),
        .ResPCSel(ResPCSel),
        .ResExSel(ResExSel),
        .FPUOp(FPUOp)
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
        .is_high(is_high),
        .valid_MDU(valid_MDU),
        .MulDivControl(MulDivControl)
    );

    FPUDecoder FPUDecoder_inst(
        .FPUOp(FPUOp),
        .funct7(funct7),
        .funct5(funct5),
        .funct3(funct3),
        .Valid_FPU(Valid_FPU),
        .FPUControl(FPUControl)
    );
    
endmodule