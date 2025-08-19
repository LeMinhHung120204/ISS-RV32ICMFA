`timescale 1ns/1ps
module RV32I #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32
)(
    input clk, rst_n
);
    wire [WIDTH_DATA - 1:0] RD1, RD2, RDF, RD1E, RD2E ,SrcAE, SrcBE, Data;
    wire [WIDTH_DATA - 1:0] InstrD, ReadDataM, ReadDataW;
    wire [WIDTH_DATA - 1:0] ImmExtD, ImmExtE, ALUResultE, ALUResultM, ALUResultW, WriteDataE, WriteDataM;
    wire [WIDTH_ADDR - 1:0] PCF, PCD, PCE ,PCNext, PCPlus4F, PCPlus4D, PCPlus4E, PCPlus4M, PCPlus4W, PCTargetE;
    reg  [WIDTH_DATA - 1:0] ResultW;

    // ----------------------- Tin hieu dieu khien -----------------------
    wire RegWriteD, RegWriteE, RegWriteM, RegWriteW, MemWriteD, MemWriteE, MemWriteM, JumpD, JumpE, BranchD, BranchE, ALUSrcD, ALUSrcE;
    wire [1:0] ResultSrcD, ResultSrcE, ResultSrcM, ResultSrcW, ImmSrcD, ImmSrcE, PCSrcE;
    wire [2:0] ALUControlD, ALUControlE;

    assign SrcAE        = RD1E;
    assign SrcBE        = (ALUSrcE == 1'b1) ? ImmExtE : RD2E;
    assign WriteDataE   = RD2E;
    assign PCPlus4F     = PCF + 32'd4;
    assign PCTargetE    = PCE + ImmExtE;
    assign PCSrcE       = JumpE | (ZeroE & BranchE);
    assign PCNext       = (PCSrcE == 1'b1) ? PCTargetE : PCPlus4F;

    always @(*) begin
        case(ResultSrcW)
            2'b00: ResultW = ALUResultW;
            2'b01: ResultW = ReadDataW;
            2'b10: ResultW = PCPlus4W;
            default: ResultW = 32'd0;
        endcase
    end 

    ControlUnit ControlUnit_ins(
        .op(InstrD[6:0]),
        .funct3(InstrD[14:12]),
        .funct7_5(InstrD[30]),
        .Zero(ZeroE),
        .PCSrc(PCSrcD),
        .ResultSrc(ResultSrcD),
        .MemWrite(MemWriteD),
        .ALUControl(ALUControlD),
        .ALUSrc(ALUSrcD),
        .ImmSrc(ImmSrcD),
        .RegWrite(RegWriteD),
        .Branch(BranchD),
        .Jump(JumpD)
    );

    PC PC_inst(
        .clk(clk),
        .rst_n(rst_n),
        .PCNext(PCNext),
        .PC(PCF)
    );

    Ins_Mem instruction_memory(
        .clk(clk),
        .addr(PCF),
        .instruction(RDF)
    );

    IF_ID IF_ID_register(
        .clk(clk),
        .rst_n(rst_n),
        .RDF(RDF),
        .PCF(PCF),
        .PCPlus4F(PCPlus4F),
        .InstrD(InstrD),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D)
    );

    RegFile register_file(
        .clk(clk),
        .rst_n(rst_n),
        .we(RegWriteW),
        .rs1(InstrD[19:15]),
        .rs2(InstrD[24:20]),
        .rd(InstrD[11:7]),
        .wd(ResultW),
        .rd1(RD1),
        .rd2(RD2)
    );

    Extend extend_inst(
        .ImmSrc(ImmSrcD),
        .Instr(InstrD[31:0]),
        .ImmExt(ImmExtD)
    );

    ID_EX ID_EX_register(
        .clk(clk),
        .rst_n(rst_n),
        .RD1(RD1),
        .RD2(RD2),
        .ImmExtD(ImmExtD),
        .PCPlus4D(PCPlus4D),
        .RegWriteD(RegWriteD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUSrcD(ALUSrcD),
        .ResultSrcD(ResultSrcD),
        .ImmSrcD(ImmSrcD),
        .ALUControlD(ALUControlD),

        .RD1E(RD1E),
        .RD2E(RD2E),
        .ImmExtE(ImmExtE),
        .PCE(PCE),
        .PCPlus4E(PCPlus4E),
        .RegWriteE(RegWriteE),
        .MemWriteE(MemWriteE),
        .JumpE(JumpE),
        .BranchE(BranchE),
        .ALUSrcE(ALUSrcE),
        .ResultSrcE(ResultSrcE),
        .ImmSrcE(ImmSrcE),
        .ALUControlE(ALUControlE)
    );

    ALU alu_inst(
        .ALUControl(ALUControlE),
        .in1(SrcAE),
        .in2(SrcBE),
        .result(ALUResultE),
        .zero(ZeroE)
    );

    EX_MEM EX_MEM_register(
        .clk(clk),
        .rst_n(rst_n),
        .ALUResultE(ALUResultE),
        .WriteDataE(WriteDataE),
        .PCPlus4E(PCPlus4E),
        .RegWriteE(RegWriteE),
        .MemWriteE(MemWriteE),
        .ResultSrcE(ResultSrcE),

        .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM),
        .PCPlus4M(PCPlus4M),
        .RegWriteM(RegWriteM),
        .MemWriteM(MemWriteM),
        .ResultSrcM(ResultSrcM)
    );

    DataMem data_memory(
        .clk(clk),
        .rst_n(rst_n),
        .MemWrite(MemWriteM),
        .addr(ALUResultM),
        .data_in(WriteDataM),
        .rd(ReadDatM)
    );

    MEM_WB MEM_WB_register(
        .clk(clk),
        .rst_n(rst_n),
        .ALUResultM(ALUResultM),
        .ReadDataM(ReadDataM),
        .PCPlus4M(PCPlus4M),
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),

        .ALUResultW(ALUResultW),
        .ReadDataW(ReadDataW),
        .PCPlus4W(PCPlus4W),
        .RegWriteW(RegWriteW),
        .ResultSrcW(ResultSrcW),
    );
endmodule