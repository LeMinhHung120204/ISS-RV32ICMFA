`timescale 1ns/1ps
module RV32I #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32
)(
    input clk, rst_n
);
    wire [WIDTH_DATA - 1:0] RD1, RD2, F_RD, E_RD1, E_RD2;
    wire [WIDTH_DATA - 1:0] D_Instr, M_ReadData, W_ReadData;
    wire [WIDTH_DATA - 1:0] D_ImmExt, E_ImmExt, M_ImmExt, W_ImmExt, E_ALUResult, M_ALUResult, W_ALUResult, M_WriteData;
    wire [4:0] E_Rs1, E_Rs2, E_Rd, M_Rd, W_Rd, A1, A2, WD3;

    wire [WIDTH_ADDR - 1:0] F_PC, D_PC, E_PC ,PCNext, F_PCPlus4, D_PCPlus4, E_PCPlus4, M_PCPlus4, W_PCPlus4, E_PCTarget, M_PCTarget, W_PCTarget;
    
    wire [WIDTH_DATA - 1:0] W_Result, E_SrcA, E_SrcB;
    wire [WIDTH_DATA - 1:0] E_WriteData;

    // ----------------------- Tin hieu dieu khien -----------------------
    wire D_RegWrite, D_MemWrite, D_Jump, D_Branch, D_ALUSrc;
    wire E_signed_less, E_RegWrite, E_MemWrite, E_Jump, E_Branch, E_ALUSrc, E_Zero, E_PCSrc, E_funct3;
    wire M_RegWrite, M_MemWrite;
    wire W_RegWrite;
    wire [2:0] D_ResultSrc, E_ResultSrc, M_ResultSrc, W_ResultSrc;
    wire [2:0] D_ImmSrc;
    wire [3:0] D_ALUControl, E_ALUControl;

    // ----------------------- Tin hieu Hazard -----------------------
    wire F_Stall, D_Stall, D_Flush, E_Flush;
    wire [1:0] ForwardAE, ForwardBE;

    // assign E_WriteData  = E_RD2;
    assign F_PCPlus4    = F_PC + 32'd4;
    assign E_PCTarget   = E_PC + E_ImmExt;
    assign PCNext       = (E_PCSrc == 1'b1) ? E_PCTarget : F_PCPlus4;
    // assign E_PCSrc      = E_Jump | (E_Zero & E_Branch);
    
    assign A1   = D_Instr[19:15];
    assign A2   = D_Instr[24:20];
    assign WD3  = D_Instr[11:7];

    // mux4_1 mux_W_Result (
    //     .in0(W_ALUResult),
    //     .in1(W_ReadData),
    //     .in2(W_PCPlus4),
    //     .in3(32'd0),
    //     .sel(W_ResultSrc),
    //     .res(W_Result)
    // );
    mux8_1 mux_W_Result (
        .in0(W_ALUResult),
        .in1(W_ReadData),
        .in2(W_PCPlus4),
        .in3(W_ImmExt),
        .in4(W_PCTarget),
        .in5(32'd0),
        .in6(32'd0),
        .in7(32'd0),
        .sel(W_ResultSrc),
        .res(W_Result)
    );

    mux4_1 mux_ForwardAE (
        .in0(E_RD1),
        .in1(W_Result),
        .in2(M_ALUResult),
        .in3(32'd0),
        .sel(ForwardAE),
        .res(E_SrcA)
    );

    mux4_1 mux_ForwardBE (
        .in0(E_RD2),
        .in1(W_Result),
        .in2(M_ALUResult),
        .in3(32'd0),
        .sel(ForwardBE),
        .res(E_WriteData)
    );

    mux2_1 mux_E_ALUSrc (
        .in0(E_WriteData),
        .in1(E_ImmExt),
        .sel(E_ALUSrc),
        .res(E_SrcB)
    );

    HazardUnit HazardUnit_inst(
        .F_Stall(F_Stall),
        .D_Rs1(A1),
        .D_Rs2(A2),
        .D_Stall(D_Stall),
        .D_Flush(D_Flush),
        .E_Rs1(E_Rs1),
        .E_Rs2(E_Rs2),
        .E_Rd(E_Rd),
        .E_PCSrc(E_PCSrc),
        .E_ResultSrc(E_ResultSrc),
        .E_Flush(E_Flush),
        .M_RegWrite(M_RegWrite),
        .M_Rd(M_Rd),
        .W_Rd(W_Rd),
        .W_RegWrite(W_RegWrite),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE)
        
    );
    BranchDecoder BranchDecoder_inst(
        .E_Jump(E_Jump),
        .E_Zero(E_Zero),
        .E_Branch(E_Branch),
        .E_signed_less(E_signed_less),
        .funct3(E_funct3),
        .E_PCSrc(E_PCSrc)
    );

    ControlUnit ControlUnit_ins(
        .op(D_Instr[6:0]),
        .funct3(D_Instr[14:12]),
        .funct7_5(D_Instr[30]),
        .Zero(E_Zero),
        .ResultSrc(D_ResultSrc),
        .MemWrite(D_MemWrite),
        .ALUControl(D_ALUControl),
        .ALUSrc(D_ALUSrc),
        .ImmSrc(D_ImmSrc),
        .RegWrite(D_RegWrite),
        .Branch(D_Branch),
        .Jump(D_Jump)
    );

    PC PC_inst(
        .clk(clk),
        .rst_n(rst_n),
        .EN(F_Stall),
        .PCNext(PCNext),
        .PC(F_PC)
    );

    Ins_Mem instruction_memory(
        .addr(F_PC),
        .instruction(F_RD)
    );

    IF_ID IF_ID_register(
        .clk(clk),
        .rst_n(rst_n),
        .EN(D_Stall),
        .D_Flush(D_Flush),
        .F_RD(F_RD),
        .F_PC(F_PC),
        .F_PCPlus4(F_PCPlus4),
        .D_Instr(D_Instr),
        .D_PC(D_PC),
        .D_PCPlus4(D_PCPlus4)
    );

    RegFile register_file(
        .clk(clk),
        .rst_n(rst_n),
        .we(W_RegWrite),
        .rs1(A1),
        .rs2(A2),
        .rd(W_Rd),
        .wd(W_Result),
        .rd1(RD1),
        .rd2(RD2)
    );

    Extend extend_inst(
        .ImmSrc(D_ImmSrc),
        .Instr(D_Instr[31:0]),
        .ImmExt(D_ImmExt)
    );

    ID_EX ID_EX_register(
        .clk(clk),
        .rst_n(rst_n),
        .E_Flush(E_Flush),
        .RD1(RD1),
        .RD2(RD2),
        .D_Rs1(A1),
        .D_Rs2(A2),
        .D_Rd(WD3),
        .D_ImmExt(D_ImmExt),
        .D_PC(D_PC),
        .D_PCPlus4(D_PCPlus4),
        .D_RegWrite(D_RegWrite),
        .D_MemWrite(D_MemWrite),
        .D_Jump(D_Jump),
        .D_Branch(D_Branch),
        .D_ALUSrc(D_ALUSrc),
        .D_ResultSrc(D_ResultSrc),
        // .D_ImmSrc(D_ImmSrc),
        .D_funct3(D_Instr[14:12]),
        .D_ALUControl(D_ALUControl),

        .E_RD1(E_RD1),
        .E_RD2(E_RD2),
        .E_Rs1(E_Rs1),
        .E_Rs2(E_Rs2),
        .E_Rd(E_Rd),
        .E_ImmExt(E_ImmExt),
        .E_PC(E_PC),
        .E_PCPlus4(E_PCPlus4),
        .E_RegWrite(E_RegWrite),
        .E_MemWrite(E_MemWrite),
        .E_Jump(E_Jump),
        .E_Branch(E_Branch),
        .E_ALUSrc(E_ALUSrc),
        .E_ResultSrc(E_ResultSrc),
        // .E_ImmSrc(E_ImmSrc),
        .E_funct3(E_funct3),
        .E_ALUControl(E_ALUControl)
    );

    ALU alu_inst(
        .ALUControl(E_ALUControl),
        .in1(E_SrcA),
        .in2(E_SrcB),
        .result(E_ALUResult),
        .zero(E_Zero),
        .signed_less(E_signed_less)
    );

    EX_MEM EX_MEM_register(
        .clk(clk),
        .rst_n(rst_n),
        .E_ALUResult(E_ALUResult),
        .E_WriteData(E_WriteData),
        .E_ImmExt(E_ImmExt),
        .E_PCPlus4(E_PCPlus4),
        .E_PCTarget(E_PCTarget),
        .E_Rd(E_Rd),
        .E_RegWrite(E_RegWrite),
        .E_MemWrite(E_MemWrite),
        .E_ResultSrc(E_ResultSrc),

        .M_ALUResult(M_ALUResult),
        .M_WriteData(M_WriteData),
        .M_ImmExt(M_ImmExt),
        .M_PCPlus4(M_PCPlus4),
        .M_PCTarget(M_PCTarget),
        .M_Rd(M_Rd),
        .M_RegWrite(M_RegWrite),
        .M_MemWrite(M_MemWrite),
        .M_ResultSrc(M_ResultSrc)
    );

    DataMem data_memory(
        .clk(clk),
        .rst_n(rst_n),
        .MemWrite(M_MemWrite),
        .addr(M_ALUResult[7:0]),
        .data_in(M_WriteData),
        .rd(M_ReadData)
    );

    MEM_WB MEM_WB_register(
        .clk(clk),
        .rst_n(rst_n),
        .M_ALUResult(M_ALUResult),
        .M_ReadData(M_ReadData),
        .M_ImmExt(M_ImmExt),
        .M_PCTarget(M_PCTarget),
        .M_PCPlus4(M_PCPlus4),
        .M_Rd(M_Rd),
        .M_RegWrite(M_RegWrite),
        .M_ResultSrc(M_ResultSrc),

        .W_ALUResult(W_ALUResult),
        .W_ReadData(W_ReadData),
        .W_ImmExt(W_ImmExt),
        .W_PCTarget(W_PCTarget),
        .W_PCPlus4(W_PCPlus4),
        .W_Rd(W_Rd),
        .W_RegWrite(W_RegWrite),
        .W_ResultSrc(W_ResultSrc)
    );
endmodule