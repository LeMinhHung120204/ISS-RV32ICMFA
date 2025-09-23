`timescale 1ns/1ps
module RV32I #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32
)(
    input   clk, rst_n,
    output  W_Result_output
    // input   [WIDTH_DATA - 1:0]  imem_instr, dmem_rdata,
    // output  [WIDTH_ADDR - 1:0]  imem_addr, 
    // output  [WIDTH_DATA - 1:0]  dmem_wdata,
    // output  [7:0]               dmem_addr,
    // output                      dmem_we
);
    wire [WIDTH_DATA - 1:0] RD1, RD2, F_RD, E_RD1, E_RD2;
    wire [WIDTH_DATA - 1:0] D_Instr, M_ReadData, W_ReadData;
    wire [WIDTH_DATA - 1:0] D_ImmExt, E_ImmExt, M_ImmExt, W_ImmExt, E_ALUResult, M_ALUResult, W_ALUResult, M_WriteData;
    wire [4:0]              E_Rs1, E_Rs2, E_Rd, M_Rd, W_Rd, A1, A2, WD3;

    wire [WIDTH_ADDR - 1:0] F_PC, D_PC, E_PC ,PCNext, F_PCPlus4, D_PCPlus4, E_PCPlus4, M_PCPlus4, W_PCPlus4, E_PCTarget, M_PCTarget, W_PCTarget;
    wire [WIDTH_DATA - 1:0] W_Result, E_SrcA, E_SrcB;
    wire [WIDTH_DATA - 1:0] E_WriteData;

    // ----------------------- Tin hieu dieu khien -----------------------
    wire D_RegWrite, D_MemWrite, D_Jump, D_Branch, D_ALUSrc;
    wire E_signed_less, E_RegWrite, E_MemWrite, E_Jump, E_Branch, E_ALUSrc, E_Zero, E_PCSrc;
    wire M_RegWrite, M_MemWrite;
    wire W_RegWrite;
    wire PCTargetSrc;
    wire [2:0] D_ResultSrc, E_ResultSrc, M_ResultSrc, W_ResultSrc;
    wire [2:0] D_ImmSrc, E_funct3;
    wire [3:0] D_ALUControl, E_ALUControl;
    wire [2:0] D_StoreSrc, E_StoreSrc, M_StoreSrc;

    // ----------------------- Tin hieu dieu khien MulDiv -----------------------
    wire [WIDTH_DATA - 1:0] E_MulHigh, E_MulLow, E_MulOut, M_MulOut, W_MulOut;
    wire [WIDTH_DATA - 1:0] E_quotient, M_quotient, W_quotient;
    wire [WIDTH_DATA - 1:0] E_remainder, M_remainder, W_remainder;
    wire [1:0] Mul_Div_unsigned;
    wire is_high;

    // ----------------------- Tin hieu Hazard -----------------------
    wire F_Stall, D_Stall, D_Flush, E_Flush;
    wire [1:0] ForwardAE, ForwardBE;

    // ----------------------- Tin hieu PC -----------------------
    assign F_PCPlus4    = F_PC + 32'd4;
    mux4_1 mux4_1_PC(
        .in0(F_PCPlus4),
        .in1(F_PCPlus4),
        .in2(E_PC + E_ImmExt),
        .in3(E_ALUResult),
        .sel({E_PCSrc, PCTargetSrc}),
        .res(PCNext)
    );

    assign W_Result_output = W_Result;
    // assign E_PCTarget   = (PCTargetSrc == 1'b1) ? E_ALUResult   : E_PC + E_ImmExt;
    // assign PCNext       = (E_PCSrc == 1'b1)     ? E_PCTarget    : F_PCPlus4;
    
    // ----------------------- Tin Hieu Ins_Mem -----------------------
    // assign imem_addr    = F_PC;
    // assign F_RD         = imem_instr;

    // ----------------------- Tin Hieu Data Mem -----------------------
    // assign dmem_we      = M_MemWrite;
    // assign dmem_addr    = M_ALUResult[7:0];
    // assign dmem_wdata   = M_WriteData;
    // assign M_ReadData   = dmem_rdata;

    // ----------------------------------------------
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
        .in5(W_MulOut),
        .in6(W_quotient),
        .in7(W_remainder),
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

    mux2_1 mux_E_MulOut (
        .in0(E_MulLow),
        .in1(E_MulHigh),
        .sel(is_high),
        .res(E_MulOut)
    );

    HazardUnit HazardUnit_inst(
        .D_Rs1(A1),
        .D_Rs2(A2),
        .E_Rs1(E_Rs1),
        .E_Rs2(E_Rs2),
        .E_Rd(E_Rd),
        .E_PCSrc(E_PCSrc),
        .E_ResultSrc(E_ResultSrc),
        .M_RegWrite(M_RegWrite),
        .M_Rd(M_Rd),
        .W_Rd(W_Rd),
        .W_RegWrite(W_RegWrite),
        
        .F_Stall(F_Stall),
        .D_Stall(D_Stall),
        .D_Flush(D_Flush),
        .E_Flush(E_Flush),
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
        .funct7(D_Instr[31:25]),
        .ResultSrc(D_ResultSrc),
        .MemWrite(D_MemWrite),
        .ALUControl(D_ALUControl),
        .ALUSrc(D_ALUSrc),
        .ImmSrc(D_ImmSrc),
        .RegWrite(D_RegWrite),
        .Branch(D_Branch),
        .Jump(D_Jump),
        .PCTargetSrc(PCTargetSrc),
        .StoreSrc(D_StoreSrc),
        .Mul_Div_unsigned(Mul_Div_unsigned),
        .is_high(is_high)
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
        .D_StoreSrc(D_StoreSrc),
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
        .E_StoreSrc(E_StoreSrc),
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

   mul32 mul_inst(
       .clk(clk),
       .rst_n(rst_n),
       .is_unsigned(Mul_Div_unsigned),
       .a(E_SrcA),
       .b(E_WriteData),
       .R_high(E_MulHigh),
       .R_low(E_MulLow)
   );

   non_restore_v2 div_inst(
       .clk(clk),
       .rst_n(rst_n),
       .is_unsigned(Mul_Div_unsigned[0]),
       .dividend(E_SrcA),
       .divisor(E_WriteData),
       .quotient(E_quotient),
       .remainder(E_remainder)
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
        .E_StoreSrc(E_StoreSrc),
        .E_MulOut(E_MulOut),
        .E_quotient(E_quotient),
        .E_remainder(E_remainder),

        .M_ALUResult(M_ALUResult),
        .M_WriteData(M_WriteData),
        .M_ImmExt(M_ImmExt),
        .M_PCPlus4(M_PCPlus4),
        .M_PCTarget(M_PCTarget),
        .M_Rd(M_Rd),
        .M_RegWrite(M_RegWrite),
        .M_MemWrite(M_MemWrite),
        .M_ResultSrc(M_ResultSrc),
        .M_StoreSrc(M_StoreSrc),
        .M_MulOut(M_MulOut),
        .M_quotient(M_quotient),
        .M_remainder(M_remainder)
    );

    DataMem data_memory(
        .clk(clk),
        .rst_n(rst_n),
        .StoreSrc(M_StoreSrc),
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
        .M_ImmExt(M_ImmExt),
        .M_PCTarget(M_PCTarget),
        .M_PCPlus4(M_PCPlus4),
        .M_Rd(M_Rd),
        .M_RegWrite(M_RegWrite),
        .M_ResultSrc(M_ResultSrc),
        .M_MulOut(M_MulOut),
        .M_quotient(M_quotient),
        .M_remainder(M_remainder),

        .W_ALUResult(W_ALUResult),
        .W_ReadData(W_ReadData),
        .W_ImmExt(W_ImmExt),
        .W_PCTarget(W_PCTarget),
        .W_PCPlus4(W_PCPlus4),
        .W_Rd(W_Rd),
        .W_RegWrite(W_RegWrite),
        .W_ResultSrc(W_ResultSrc),
        .W_MulOut(W_MulOut),
        .W_quotient(W_quotient),
        .W_remainder(W_remainder)
    );
endmodule