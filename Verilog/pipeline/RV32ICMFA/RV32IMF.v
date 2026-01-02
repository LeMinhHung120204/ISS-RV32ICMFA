`timescale 1ns/1ps
module RV32IMF #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32
)(
    input   clk, rst_n,

    // cpu <-> dcache
    input   [WIDTH_DATA-1:0]    data_rdata,
    input                       dcache_stall,
    output                      data_req,
    output                      data_wr,
    output  [1:0]               data_size,
    output  [WIDTH_ADDR - 1:0]  data_addr,
    output  [WIDTH_DATA - 1:0]  data_wdata,

    // cpu <-> icache
    input                       icache_stall,
    input   [WIDTH_DATA - 1:0]  imem_instr,

    output                      icache_req,
    output                      icache_flush,
    output  [WIDTH_ADDR - 1:0]  icache_addr,

    output  [WIDTH_DATA - 1:0]  W_Result_output
    // input   [WIDTH_DATA - 1:0]  imem_instr, dmem_rdata,
    // output  [WIDTH_ADDR - 1:0]  imem_addr, 
    // output  [WIDTH_DATA - 1:0]  dmem_wdata,
    // output  [7:0]               dmem_addr,
    // output                      dmem_we
);
    wire [WIDTH_DATA - 1:0] RDX1, RDX2, RDF1, RDF2, RDF3, F_RD, D_RD1, D_RD2;
    wire [WIDTH_DATA - 1:0] E_RD1, E_RD2, E_RDF2, E_RD3;
    wire [WIDTH_DATA - 1:0] D_Instr, D_ImmExt;
    wire [WIDTH_DATA - 1:0] E_ImmExt, E_ALUResult;
    wire [WIDTH_DATA - 1:0] M_Result, C_Result;
    wire [WIDTH_DATA - 1:0] M_ReadData, M_ALUResult, M_WriteData;
    wire [WIDTH_DATA - 1:0] M_ImmExt, C_ImmExt;
    wire [WIDTH_DATA - 1:0] C_mux_result, C_ReadData;
    wire [WIDTH_DATA - 1:0] W_ImmExt, W_ReadData, W_Result, WB_Result, W_mux_result;
    wire [4:0]              E_rs1, E_rs2, E_rd, E_RsF3;
    wire [4:0]              M_rd, C_rd, W_rd;
    wire [4:0]              A1, A2, A3, WD3;

    wire [WIDTH_DATA - 1:0] E_SrcA, E_SrcB, E_SrcFA, E_SrcFB, E_SrcFC;
    wire [WIDTH_DATA - 1:0] E_WriteData;

    // ----------------------- Tin hieu dieu khien -----------------------
    wire    D_RegWrite, D_MemWrite, D_Jump, D_Branch, D_ALUSrc, D_FRegWrite, D_addr_addend_sel, D_ResPCSel, 
            D_valid_MDU, D_Valid_FPU, D_RegSrc1, D_RegSrc2;
    wire    E_signed_less, E_RegWrite, E_MemWrite, E_Jump, E_Branch, E_ALUSrc, E_Zero, E_PCSrc, E_addr_addend_sel, E_ResPCSel,
            E_valid_MDU, E_FRegWrite, E_Valid_FPU, E_MDU_FPUEn, E_RegSrc1;
    wire    M_RegWrite, M_MemWrite, M_FRegWrite, M_ResPCSel, M_MDU_FPUEn;
    wire    C_RegWrite, C_FRegWrite, C_MDU_FPUEn;
    wire    W_RegWrite, W_FRegWrite, W_MDU_FPUEn;
    wire    D_is_high, E_is_high;
    
    wire [4:0] D_FPUControl, E_FPUControl;
    wire [3:0] D_ALUControl, E_ALUControl;
    wire [2:0] D_ResultSrc, E_ResultSrc, M_ResultSrc, C_ResultSrc, W_ResultSrc;
    wire [2:0] D_ImmSrc, E_funct3;
    wire [2:0] D_StoreSrc, E_StoreSrc, M_StoreSrc;
    wire [1:0] D_ResExSel, D_Mul_Div_unsigned, D_MulDivControl, E_Mul_Div_unsigned, E_MulDivControl, E_ResExSel, M_ResExSel;

    // ----------------------- Tin hieu dieu khien MDU -----------------------
    wire [WIDTH_DATA - 1:0] E_MDUResult, M_MDUResult;
    wire [1:0] Mul_Div_unsigned;
    wire is_high, E_MDU_done, E_MulDivStall;

    // ----------------------- Tin hieu dieu khien FPU -----------------------
    wire [WIDTH_DATA-1:0] E_FPUResult, M_FPUResult;
    // wire E_FPU_done, E_FPUStall;

    // ----------------------- Tin hieu Hazard -----------------------
    wire F_Stall, D_Stall, E_Stall;
    wire D_Flush, fetch_pipe_Flush, E_Flush;
    wire [1:0] ForwardAE, ForwardBE, ForwardFCE;

    // ----------------------- Tin hieu PC -----------------------
    reg [WIDTH_ADDR - 1:0] PCNext;
    wire [WIDTH_ADDR - 1:0] F_PC, D_PC, E_PC;
    wire [WIDTH_ADDR - 1:0] F_PCPlus4, D_PCPlus4, E_PCPlus4, M_PCPlus4, W_PCPlus4;
    wire [WIDTH_ADDR - 1:0] E_PCtmp;
    wire [WIDTH_ADDR - 1:0] M_ResPC, C_ResPC, W_ResPC;
    wire [WIDTH_ADDR - 1:0] E_PCTarget, M_PCTarget;

    // ----------------------- Tin hieu Branch prediction -----------------------
    wire        F_Predict_Taken, D_Predict_Taken, E_Predict_Taken;  
    wire [2:0]  F_GHSR, D_GHSR, E_GHSR;
    wire [31:0] F_Predict_Target, D_Predict_Target, E_Predict_Target;

    wire        E_Mispredict; 
    wire [31:0] E_Correct_PC;
    

    assign W_Result_output  = W_mux_result;
    

    // ---------------------------------------- Branch prediction ----------------------------------------
    assign F_PCPlus4    = F_PC + 32'd4;
    assign E_Mispredict = (E_PCSrc != E_Predict_Taken);
    assign E_Correct_PC = E_PCSrc ? E_PCTarget : E_PCPlus4;
    

    always @(*) begin
        case ({E_Mispredict, F_Predict_Taken})
            // TH1: Mispredict = 1. uu tien sua sai
            2'b10, 2'b11: PCNext = E_Correct_PC; 
            
            // TH2: Mispredict = 0, Predict_Taken = 1.
            2'b01:        PCNext = F_Predict_Target;
            default:      PCNext = F_PCPlus4;
        endcase
    end

    BPU #(
        .W_ADDR(WIDTH_ADDR)
    ) BPU_inst (
        .clk            (clk),
        .rst_n          (rst_n),

        // IF state
        .F_PC           (F_PC),
        .predict_taken  (F_Predict_Taken), 
        .target_pc      (F_Predict_Target),
        .F_GHSR         (F_GHSR),

        // EX state
        .E_PC           (E_PC),
        .E_PCTarget     (E_PCTarget), 
        .E_Branch       (E_Branch),
        .E_Jump         (E_Jump),
        .taken          (E_PCSrc),
        .E_GHSR         (E_GHSR)
    );

    BranchDecoder BranchDecoder_inst(
        .E_Jump         (E_Jump),
        .E_Zero         (E_Zero),
        .E_Branch       (E_Branch),
        .E_signed_less  (E_signed_less),
        .funct3         (E_funct3),
        .E_PCSrc        (E_PCSrc)
    );
    // ---------------------------------------- WB state ----------------------------------------

    assign icache_flush = fetch_pipe_Flush;
    // mux4_1 mux_W_Result (
    //     .in0    (W_Result),
    //     .in1    (W_ReadData),
    //     .in2    (W_ResPC),
    //     .in3    (W_ImmExt),
    //     .sel    (W_ResultSrc[1:0]),
    //     .res    (WB_Result)
    // );

    assign A1   = D_Instr[19:15];
    assign A2   = D_Instr[24:20];
    assign A3   = D_Instr[31:27];
    assign WD3  = D_Instr[11:7];
    HazardUnit HazardUnit_inst(
        .D_Rs1          (A1),
        .D_Rs2          (A2),
        .E_Rs1          (E_rs1),
        .E_Rs2          (E_rs2),
        .E_RsF3         (E_RsF3),
        .E_rd           (E_rd),
        .icache_stall   (icache_stall),
        .dcache_stall   (dcache_stall),
        // .E_PCSrc        (E_PCSrc),
        .E_MulDivStall  (E_MulDivStall),
        .E_FPUStall     (E_FPUStall),
        .E_ResultSrc    (E_ResultSrc),
        .E_RegSrc1      (E_RegSrc1),
        .E_RegSrc2      (E_RegSrc2),
        .E_Mispredict   (E_Mispredict),
        .M_RegWrite     (M_RegWrite),
        .M_FRegWrite    (M_FRegWrite),
        .C_RegWrite     (C_RegWrite),
        .C_FRegWrite    (C_FRegWrite),
        .M_Rd           (M_rd),
        .C_Rd           (C_rd),
        .W_Rd           (W_rd),
        .W_RegWrite     (W_RegWrite),
        .W_FRegWrite    (W_FRegWrite),
        .W_MDU_FPUEn    (W_MDU_FPUEn),
        
        .F_Stall            (F_Stall),
        .D_Stall            (D_Stall),
        .E_Stall            (E_Stall),
        .D_Flush            (D_Flush),
        .fetch_pipe_Flush   (fetch_pipe_Flush),
        .E_Flush            (E_Flush),
        .ForwardAE          (ForwardAE),
        .ForwardBE          (ForwardBE),
        .ForwardFCE         (ForwardFCE)
    );
    // ---------------------------------------- IF state ----------------------------------------
    PC PC_inst(
        .clk    (clk),
        .rst_n  (rst_n),
        .EN     (F_Stall),
        .PCNext (PCNext),
        .PC     (F_PC)
    );

    // ---------------------------------------- CACHE CONNECTION ----------------------------------------
    wire                    s2_Predict_Taken;
    wire [2:0]              s2_GHSR         ;
    wire [WIDTH_ADDR-1:0]   s2_PC           ;
    wire [WIDTH_ADDR-1:0]   s2_PCPlus4      ;

    assign icache_addr = F_PC;          // S1 -> Cache
    assign icache_req  = rst_n;         // luon yeu canh lenh khi khong reset
    assign F_RD        = imem_instr;    // S2 (Cache) -> 

    // Ins_Mem instruction_memory(
    //     .addr       (F_PC),
    //     .instruction(F_RD)
    // );
    // ---------------------------------------- fetch_pipe REGISTER (IF -> S2) ----------------------------------------

    fetch_pipe fetch_pipe_register (
        .clk    (clk),
        .rst_n  (rst_n),
        .EN     (icache_stall),
        .Flush  (fetch_pipe_Flush),

        .s1_Predict_Taken   (F_Predict_Taken),
        .s1_GHSR            (F_GHSR),
        .s1_PC              (F_PC),
        .s1_PCPlus4         (F_PCPlus4),

        .s2_Predict_Taken   (s2_Predict_Taken),
        .s2_GHSR            (s2_GHSR         ),
        .s2_PC              (s2_PC           ),
        .s2_PCPlus4         (s2_PCPlus4      )
    );

    // ---------------------------------------- IF/ID REGISTER (S2 -> Decode) ----------------------------------------

    IF_ID IF_ID_register(
        .clk                (clk),
        .rst_n              (rst_n),
        .EN                 (D_Stall),
        .D_Flush            (D_Flush),
        .F_RD               (F_RD),
        .F_PC               (s2_PC),
        .F_PCPlus4          (s2_PCPlus4),
        .F_GHSR             (s2_GHSR),
        .F_Predict_Taken    (s2_Predict_Taken),

        .D_Instr            (D_Instr),
        .D_PC               (D_PC),
        .D_PCPlus4          (D_PCPlus4),
        .D_GHSR             (D_GHSR),
        .D_Predict_Taken    (D_Predict_Taken)
    );

    // ---------------------------------------- ID state ----------------------------------------
    wire D_data_req, E_data_req;
    
    ControlUnit ControlUnit_ins(
        .op                 (D_Instr[6:0]),
        .funct3             (D_Instr[14:12]),
        .funct7             (D_Instr[31:25]),
        .funct5             (D_Instr[24:20]),
        .ResultSrc          (D_ResultSrc),
        .MemWrite           (D_MemWrite),
        .ALUControl         (D_ALUControl),
        .ALUSrc             (D_ALUSrc),
        .ImmSrc             (D_ImmSrc),
        .RegWrite           (D_RegWrite),
        .Branch             (D_Branch),
        .Jump               (D_Jump),
        .StoreSrc           (D_StoreSrc),
        .ResExSel           (D_ResExSel),
        .Mul_Div_unsigned   (D_Mul_Div_unsigned),
        .MulDivControl      (D_MulDivControl),
        .addr_addend_sel    (D_addr_addend_sel),
        .ResPCSel           (D_ResPCSel),
        .valid_MDU          (D_valid_MDU),
        .is_high            (D_is_high),
        .Valid_FPU          (D_Valid_FPU),
        .RegSrc1            (D_RegSrc1),
        .RegSrc2            (D_RegSrc2),
        .FPUControl         (D_FPUControl),
        .FRegWrite          (D_FRegWrite),
        .data_req           (D_data_req)
    );

    RegFile register_file(
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (W_RegWrite),
        .rs1    (A1),
        .rs2    (A2),
        .rd     (W_rd),
        .wd     (W_mux_result),
        .rd1    (RDX1),
        .rd2    (RDX2)
    );

    FRegFile FRegFile_inst(
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (W_FRegWrite),
        .rs1    (A1),
        .rs2    (A2),
        .rs3    (A3),
        .rd     (W_rd),
        .wd     (W_mux_result),
        .rd1    (RDF1),
        .rd2    (RDF2),
        .rd3    (RDF3)
    );

    Extend extend_inst(
        .ImmSrc (D_ImmSrc),
        .Instr  (D_Instr[31:0]),
        .ImmExt (D_ImmExt)
    );

    mux2_1 mux_D_RD1 (
        .in0    (RDX1),
        .in1    (RDF1),
        .sel    (D_RegSrc1),
        .res    (D_RD1)
    );

    mux2_1 mux_D_RD2 (
        .in0    (RDX2),
        .in1    (RDF2),
        .sel    (D_RegSrc2),
        .res    (D_RD2)
    );

    ID_EX ID_EX_register(
        .clk                (clk),
        .rst_n              (rst_n),
        .E_Flush            (E_Flush),
        .EN                 (E_Stall),

        .D_RD1              (D_RD1),
        .D_RD2              (D_RD2),
        .D_RDF2             (RDF2),
        .D_RD3              (RDF3),
        .D_Rs1              (A1),
        .D_Rs2              (A2),
        .D_RsF3             (A3),
        .D_rd               (WD3),
        .D_ImmExt           (D_ImmExt),
        .D_PC               (D_PC),
        .D_PCPlus4          (D_PCPlus4),
        .D_RegWrite         (D_RegWrite),
        .D_MemWrite         (D_MemWrite),
        .D_Jump             (D_Jump),
        .D_Branch           (D_Branch),
        .D_ALUSrc           (D_ALUSrc),
        .D_ResultSrc        (D_ResultSrc),
        .D_funct3           (D_Instr[14:12]),
        .D_GHSR             (D_GHSR),
        .D_StoreSrc         (D_StoreSrc),
        .D_ALUControl       (D_ALUControl),
        .D_is_high          (D_is_high),
        .D_addr_addend_sel  (D_addr_addend_sel),
        .D_ResPCSel         (D_ResPCSel),
        .D_valid_MDU        (D_valid_MDU),
        .D_FRegWrite        (D_FRegWrite),
        .D_Valid_FPU        (D_Valid_FPU),
        .D_RegSrc1          (D_RegSrc1),
        .D_RegSrc2          (D_RegSrc2),
        .D_FPUControl       (D_FPUControl),
        .D_Mul_Div_unsigned (D_Mul_Div_unsigned),
        .D_MulDivControl    (D_MulDivControl),
        .D_ResExSel         (D_ResExSel),  
        .D_Predict_Taken    (D_Predict_Taken),    
        .D_data_req         (D_data_req),  

        .E_RD1              (E_RD1),
        .E_RD2              (E_RD2),
        .E_RDF2             (E_RDF2),
        .E_RD3              (E_RD3),
        .E_Rs1              (E_rs1),
        .E_Rs2              (E_rs2),
        .E_RsF3             (E_RsF3),
        .E_rd               (E_rd),
        .E_ImmExt           (E_ImmExt),
        .E_PC               (E_PC),
        .E_PCPlus4          (E_PCPlus4),
        .E_RegWrite         (E_RegWrite),
        .E_MemWrite         (E_MemWrite),
        .E_Jump             (E_Jump),
        .E_Branch           (E_Branch),
        .E_ALUSrc           (E_ALUSrc),
        .E_ResultSrc        (E_ResultSrc),
        .E_funct3           (E_funct3),
        .E_GHSR             (E_GHSR),
        .E_StoreSrc         (E_StoreSrc),
        .E_ALUControl       (E_ALUControl),
        .E_is_high          (E_is_high),
        .E_addr_addend_sel  (E_addr_addend_sel),
        .E_ResPCSel         (E_ResPCSel),
        .E_valid_MDU        (E_valid_MDU),
        .E_FRegWrite        (E_FRegWrite),
        .E_Valid_FPU        (E_Valid_FPU),
        .E_RegSrc1          (E_RegSrc1),
        .E_RegSrc2          (E_RegSrc2),
        .E_FPUControl       (E_FPUControl),
        .E_Mul_Div_unsigned (E_Mul_Div_unsigned),
        .E_MulDivControl    (E_MulDivControl),
        .E_ResExSel         (E_ResExSel),
        .E_Predict_Taken    (E_Predict_Taken),
        .E_data_req         (E_data_req)
    );

    // ---------------------------------------- Ex state ----------------------------------------
    wire M_data_req;

    ALU alu_inst(
        .ALUControl (E_ALUControl),
        .in1        (E_SrcA),
        .in2        (E_SrcB),

        .result     (E_ALUResult),
        .zero       (E_Zero),
        .signed_less(E_signed_less)
    );

    MDU MDU_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .is_high            (E_is_high),
        .valid_input        (E_valid_MDU),
        .Mul_Div_unsigned   (E_Mul_Div_unsigned),
        .MulDivControl      (E_MulDivControl),
        .rs1                (E_SrcA),
        .rs2                (E_WriteData),

        .OutData            (E_MDUResult),
        .stall              (E_MulDivStall)
    );

    FPU FPU_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .en         (E_Valid_FPU),
        .FPUControl (E_FPUControl),
        .rs1        (E_SrcA),
        // .rs2(E_SrcFB),
        .rs2        (E_WriteData),
        .rs3        (E_SrcFC),

        .rd         (E_FPUResult),
        .stall      (E_FPUStall)
    );

    mux2_1 Mux_PCadd(
        .in0    (E_PC),
        .in1    (E_RD1),
        .sel    (E_addr_addend_sel),
        .res    (E_PCtmp)
    );

    mux4_1 mux_ForwardAE (
        .in0    (E_RD1),
        .in1    (M_Result),
        .in2    (C_mux_result),
        .in3    (W_mux_result),
        .sel    (ForwardAE),
        .res    (E_SrcA)
    );

    mux4_1 mux_ForwardBE (
        .in0    (E_RD2),
        .in1    (M_Result),
        .in2    (C_mux_result),
        .in3    (W_mux_result),
        .sel    (ForwardBE),
        .res    (E_WriteData)
    );

    mux4_1 mux_ForwardFCE (
        .in0    (E_RD3),
        .in1    (M_FPUResult),
        .in2    (C_mux_result),
        .in3    (W_mux_result),
        .sel    (ForwardFCE),
        .res    (E_SrcFC)
    );

    mux2_1 mux_E_ALUSrc (
        .in0    (E_WriteData),
        .in1    (E_ImmExt),
        .sel    (E_ALUSrc),
        .res    (E_SrcB)
    );

    assign E_PCTarget   = E_ImmExt + E_PCtmp;
    assign E_MDU_FPUEn  = E_valid_MDU | E_Valid_FPU;

    EX_MEM EX_MEM_register(
        .clk(clk),
        .rst_n(rst_n),

        .E_ALUResult    (E_ALUResult),
        .E_MDUResult    (E_MDUResult),
        .E_FPUResult    (E_FPUResult),
        .E_WriteData    (E_WriteData),
        .E_ImmExt       (E_ImmExt),
        .E_PCPlus4      (E_PCPlus4),
        .E_PCTarget     (E_PCTarget),
        .E_rd           (E_rd),
        .E_RegWrite     (E_RegWrite),
        .E_FRegWrite    (E_FRegWrite),
        .E_MemWrite     (E_MemWrite),
        .E_ResultSrc    (E_ResultSrc),
        .E_StoreSrc     (E_StoreSrc),
        .E_ResExSel     (E_ResExSel),
        .E_ResPCSel     (E_ResPCSel),
        .E_MDU_FPUEn    (E_MDU_FPUEn),
        .E_data_req     (E_data_req),

        .M_ALUResult    (M_ALUResult),
        .M_MDUResult    (M_MDUResult),
        .M_FPUResult    (M_FPUResult),
        .M_WriteData    (M_WriteData),
        .M_ImmExt       (M_ImmExt),
        .M_PCPlus4      (M_PCPlus4),
        .M_PCTarget     (M_PCTarget),
        .M_rd           (M_rd),
        .M_RegWrite     (M_RegWrite),
        .M_FRegWrite    (M_FRegWrite),
        .M_MemWrite     (M_MemWrite),
        .M_ResultSrc    (M_ResultSrc),
        .M_StoreSrc     (M_StoreSrc),
        .M_ResExSel     (M_ResExSel),
        .M_ResPCSel     (M_ResPCSel),
        .M_MDU_FPUEn    (M_MDU_FPUEn),
        .M_data_req     (M_data_req)
    );

    // ---------------------------------------- DATA CACHE INTERFACE ----------------------------------------
    assign data_wr      = M_MemWrite;
    assign data_size    = M_StoreSrc;
    assign data_addr    = M_ALUResult;
    assign data_wdata   = M_WriteData;
    assign data_req     = M_data_req;

    // ---------------------------------------- Execution Result Mux ----------------------------------------
    mux4_1 mux_Result (
        .in0    (M_ALUResult),
        .in1    (M_MDUResult),
        .in2    (M_FPUResult),
        .in3    (32'd0),
        .sel    (M_ResExSel),
        .res    (M_Result)
    );

    // ---------------------------------------- PC Result Mux ----------------------------------------
    mux2_1 mux_ResPC(
        .in0    (M_PCTarget),
        .in1    (M_PCPlus4),
        .sel    (M_ResPCSel),
        .res    (M_ResPC)
    );

    // ---------------------------------------- [PIPELINE REGISTER] MEM -> CACHE ----------------------------------------
    MEM_CACHE MEM_CACHE_register(
        .clk            (clk),
        .rst_n          (rst_n),
        .M_Result       (M_Result),
        .M_ImmExt       (M_ImmExt),
        .M_ResPC        (M_ResPC),
        .M_rd           (M_rd),
        .M_RegWrite     (M_RegWrite),
        .M_FRegWrite    (M_FRegWrite),
        .M_ResultSrc    (M_ResultSrc),
        .M_MDU_FPUEn    (M_MDU_FPUEn),

        .C_Result       (C_Result),
        .C_ImmExt       (C_ImmExt),
        .C_ResPC        (C_ResPC),
        .C_rd           (C_rd),
        .C_RegWrite     (C_RegWrite),
        .C_FRegWrite    (C_FRegWrite),
        .C_ResultSrc    (C_ResultSrc),
        .C_MDU_FPUEn    (C_MDU_FPUEn)
    );

    // ---------------------------------------- CACHE RESPONSE & FINAL SELECTION ----------------------------------------
    assign C_ReadData   = data_rdata;
    mux4_1 mux_C_Result (
        .in0    (C_Result),
        .in1    (C_ReadData),
        .in2    (C_ResPC),
        .in3    (C_ImmExt),
        .sel    (C_ResultSrc[1:0]),
        .res    (C_mux_result)
    );

    // DataMem data_memory(
    //     .clk        (clk),
    //     .rst_n      (rst_n),
    //     .StoreSrc   (M_StoreSrc),
    //     .MemWrite   (M_MemWrite),
    //     .addr       (M_ALUResult),
    //     .data_in    (M_WriteData),
    //     .rd         (M_ReadData)
    // );


    // ---------------------------------------- [PIPELINE REGISTER] CACHE -> WRITEBACK ----------------------------------------

    MEM_WB MEM_WB_register(
        .clk            (clk),
        .rst_n          (rst_n),
        // .M_Result       (C_Result),
        // .M_ReadData     (C_ReadData),
        // .M_ImmExt       (C_ImmExt),
        // .M_ResPC        (C_ResPC),
        .M_rd           (C_rd),
        .M_RegWrite     (C_RegWrite),
        .M_FRegWrite    (C_FRegWrite),
        .M_ResultSrc    (C_ResultSrc),
        .M_MDU_FPUEn    (C_MDU_FPUEn),
        .C_mux_result   (C_mux_result),

        // .W_Result       (W_Result),
        // .W_ReadData     (W_ReadData),
        // .W_ImmExt       (W_ImmExt),
        // .W_ResPC        (W_ResPC),
        .W_rd           (W_rd),
        .W_RegWrite     (W_RegWrite),
        .W_FRegWrite    (W_FRegWrite),
        .W_ResultSrc    (W_ResultSrc),
        .W_MDU_FPUEn    (W_MDU_FPUEn),
        .W_mux_result   (W_mux_result)
    );
endmodule