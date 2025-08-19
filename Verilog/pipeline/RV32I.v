`timescale 1ns/1ps
module RV32I #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32
)(
    input clk, rst_n
);
    wire [WIDTH_DATA - 1:0] RD1, RD2, F_RD, E_RD1, E_RD2;
    wire [WIDTH_DATA - 1:0] D_Instr, M_ReadData, W_ReadData;
    wire [WIDTH_DATA - 1:0] D_ImmExt, E_ImmExt, E_ALUResult, M_ALUResult, W_ALUResult, E_WriteData, M_WriteData;
    wire [4:0] E_Rs1, E_Rs2, E_Rd, M_Rd, W_Rd;

    wire [WIDTH_ADDR - 1:0] F_PC, D_PC, E_PC ,PCNext, F_PCPlus4, D_PCPlus4, E_PCPlus4, M_PCPlus4, W_PCPlus4, E_PCTarget;
    
    reg  [WIDTH_DATA - 1:0] W_Result, E_SrcA, E_SrcB;

    // ----------------------- Tin hieu dieu khien -----------------------
    wire D_RegWrite, E_RegWrite, M_RegWrite, W_RegWrite, D_MemWrite, E_MemWrite, M_MemWrite, D_Jump, E_Jump, D_Branch, E_Branch, D_ALUSrc, E_ALUSrc, E_Zero, E_PCSrc;
    wire [1:0] D_ResultSrc, E_ResultSrc, M_ResultSrc, W_ResultSrc, D_ImmSrc, E_ImmSrc;
    wire [1:0] ForwardAE, ForwardBE;
    wire [2:0] D_ALUControl, E_ALUControl;

    assign E_WriteData  = E_RD2;
    assign F_PCPlus4    = F_PC + 32'd4;
    assign E_PCTarget   = E_PC + E_ImmExt;
    assign E_PCSrc      = E_Jump | (E_Zero & E_Branch);
    assign PCNext       = (E_PCSrc == 1'b1) ? E_PCTarget : F_PCPlus4;

    always @(*) begin
        case(W_ResultSrc)
            2'b00: W_Result = W_ALUResult;
            2'b01: W_Result = W_ReadData;
            2'b10: W_Result = W_PCPlus4;
            default: W_Result = 32'd0;
        endcase

        case(ForwardAE)
            2'b00: E_SrcA = E_RD1;
            2'b01: E_SrcA = W_Result;
            2'b10: E_SrcA = M_ALUResult;
            default: E_SrcA = 32'd0;
        endcase

        casez({ForwardBE, E_ALUSrc})
            3'b000: E_SrcB = E_RD2;
            3'b010: E_SrcB = W_Result;
            3'b100: E_SrcB = M_ALUResult;
            3'b??1: E_SrcB = E_ImmExt;
            default: E_SrcB = 32'd0;
        endcase
    end 

    HazardUnit HazardUnit_inst(
        .M_RegWrite(M_RegWrite),
        .W_RegWrite(W_RegWrite),
        .E_Rs1(E_Rs1),
        .E_Rs2(E_Rs2),
        .M_Rd(M_Rd),
        .W_Rd(W_Rd),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE)
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
        .PCNext(PCNext),
        .PC(F_PC)
    );

    Ins_Mem instruction_memory(
        .clk(clk),
        .addr(F_PC),
        .instruction(F_RD)
    );

    IF_ID IF_ID_register(
        .clk(clk),
        .rst_n(rst_n),
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
        .rs1(D_Instr[19:15]),
        .rs2(D_Instr[24:20]),
        .rd(D_Instr[11:7]),
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
        .RD1(RD1),
        .RD2(RD2),
        .D_Rs1(D_Instr[19:15]),
        .D_Rs2(D_Instr[24:20]),
        .D_Rd(D_Instr[11:7]),
        .D_ImmExt(D_ImmExt),
        .D_PC(D_PC),
        .D_PCPlus4(D_PCPlus4),
        .D_RegWrite(D_RegWrite),
        .D_MemWrite(D_MemWrite),
        .D_Jump(D_Jump),
        .D_Branch(D_Branch),
        .D_ALUSrc(D_ALUSrc),
        .D_ResultSrc(D_ResultSrc),
        .D_ImmSrc(D_ImmSrc),
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
        .E_ImmSrc(E_ImmSrc),
        .E_ALUControl(E_ALUControl)
    );

    ALU alu_inst(
        .ALUControl(E_ALUControl),
        .in1(E_SrcA),
        .in2(E_SrcB),
        .result(E_ALUResult),
        .zero(E_Zero)
    );

    EX_MEM EX_MEM_register(
        .clk(clk),
        .rst_n(rst_n),
        .E_ALUResult(E_ALUResult),
        .E_WriteData(E_WriteData),
        .E_PCPlus4(E_PCPlus4),
        .E_Rd(E_Rd),
        .E_RegWrite(E_RegWrite),
        .E_MemWrite(E_MemWrite),
        .E_ResultSrc(E_ResultSrc),

        .M_ALUResult(M_ALUResult),
        .M_WriteData(M_WriteData),
        .M_PCPlus4(M_PCPlus4),
        .M_Rd(M_Rd),
        .M_RegWrite(M_RegWrite),
        .M_MemWrite(M_MemWrite),
        .M_ResultSrc(M_ResultSrc)
    );

    DataMem data_memory(
        .clk(clk),
        .rst_n(rst_n),
        .MemWrite(M_MemWrite),
        .addr(M_ALUResult),
        .data_in(M_WriteData),
        .rd(M_ReadData)
    );

    MEM_WB MEM_WB_register(
        .clk(clk),
        .rst_n(rst_n),
        .M_ALUResult(M_ALUResult),
        .M_ReadData(M_ReadData),
        .M_PCPlus4(M_PCPlus4),
        .M_Rd(M_Rd),
        .M_RegWrite(M_RegWrite),
        .M_ResultSrc(M_ResultSrc),

        .W_ALUResult(W_ALUResult),
        .W_ReadData(W_ReadData),
        .W_PCPlus4(W_PCPlus4),
        .W_Rd(W_Rd),
        .W_RegWrite(W_RegWrite),
        .W_ResultSrc(W_ResultSrc)
    );
endmodule