`timescale 1ns/1ps
module ControlUnit(
    input   [6:0]   op,
    input   [6:0]   funct7,
    input   [4:0]   funct5,
    input   [2:0]   funct3,
    
    output          MemWrite, 
    output          ALUSrc, 
    output          RegWrite, 
    output          Jump, 
    output          Branch, 
    output          is_high, 
    output          addr_addend_sel, 
    output          ResPCSel, 
    output          valid_MDU, 
    output          FRegWrite, 
    output          Valid_FPU, 
    output          RegSrc1, 
    output          RegSrc2,
    output          data_req,
    output  [4:0]   FPUControl,
    output  [3:0]   ALUControl,
    output  [2:0]   ImmSrc, 
    output  [2:0]   ResultSrc, 
    output  [2:0]   StoreSrc,
    output  [1:0]   Mul_Div_unsigned, 
    output  [1:0]   MulDivControl, 
    output  [1:0]   ResExSel
);
    wire MDUOp;
    wire [1:0] ALUOp;
    wire [2:0] FPUOp;
    MainDecoder maindecoder_inst(
        .op(op),
        .funct3(funct3),
        .funct7(funct7),
        .Branch(Branch),
        .ResultSrc(ResultSrc),
        .MemWrite(MemWrite),
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
        .MDUOp(MDUOp),
        .FPUOp(FPUOp),
        .data_req(data_req)
    );

    AluDecoder aludecoder_inst(
        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7_5(funct7[5]),
        .op_5(op[5]),
        .ALUControl(ALUControl)
    );

    MulDivDecode MulDivDecode_inst(
        .MulDivOp(MDUOp),
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
        .RegSrc1(RegSrc1),
        .RegSrc2(RegSrc2),
        .Valid_FPU(Valid_FPU),
        .FPUControl(FPUControl)
    );
    
endmodule