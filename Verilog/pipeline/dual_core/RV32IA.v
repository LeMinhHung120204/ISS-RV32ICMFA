`timescale 1ns/1ps
module RV32IA #(
    parameter WIDTH_DATA    = 32,
    parameter WIDTH_ADDR    = 32,
    parameter START_PC      = 32'd0
    // parameter END_PC        = 32'd1024
)(
    input   clk, rst_n,
    input   test_stall,

    // cpu <-> dcache
    input   [WIDTH_DATA-1:0]    data_rdata,
    input                       dcache_stall,
    input                       raw_hazard,
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
);

    // ----------------------- fetch signals -----------------------
    reg  [WIDTH_ADDR-1:0]   PCNext;
    wire [WIDTH_DATA-1:0]   F_RD;
    wire [WIDTH_ADDR-1:0]   F_PC, F_PCPlus4;
    wire                    F_Stall;
    wire                    F_Predict_Taken;
    wire [2:0]              F_GHSR;
    wire [31:0]             F_Predict_Target;
    
    // ----------------------- IF signals (S2 - after icache) -----------------------
    wire                    s2_Predict_Taken;
    wire [2:0]              s2_GHSR;
    wire [WIDTH_ADDR-1:0]   s2_PC, s2_PCPlus4;
    wire                    fetch_pipe_Flush;

    // ----------------------- ID signals -----------------------
    wire [WIDTH_DATA-1:0]   D_Instr, D_ImmExt;
    wire [WIDTH_ADDR-1:0]   D_PC, D_PCPlus4;
    wire [WIDTH_DATA-1:0]   RDX1, RDX2;
    wire [4:0]              A1, A2, WD3;
    wire                    D_RegWrite, D_MemWrite, D_Jump, D_Branch, D_ALUSrc, D_addr_addend_sel, D_ResPCSel;
    wire [3:0]              D_ALUControl;
    wire [2:0]              D_ResultSrc, D_ImmSrc, D_StoreSrc;
    wire                    D_Predict_Taken;
    wire [2:0]              D_GHSR;
    wire                    D_data_req;
    wire                    D_Stall, D_Flush;

    // ----------------------- atomic signals -----------------------
    wire            D_amo;
    wire    [2:0]   D_amo_op;
    wire            D_lr, D_sc;

    // ----------------------- EX signals -----------------------
    wire [WIDTH_DATA-1:0]   E_RD1, E_RD2;
    wire [WIDTH_DATA-1:0]   E_ImmExt, E_ALUResult;
    wire [WIDTH_ADDR-1:0]   E_PC, E_PCPlus4, E_PCtmp, E_PCTarget;
    wire [4:0]              E_rs1, E_rs2, E_rd;
    wire [WIDTH_DATA-1:0]   E_SrcA, E_SrcB, E_WriteData;
    wire                    E_signed_less, E_RegWrite, E_MemWrite, E_Jump, E_Branch, E_ALUSrc, E_Zero, E_PCSrc, E_addr_addend_sel, E_ResPCSel;
    wire [3:0]              E_ALUControl;
    wire [2:0]              E_ResultSrc, E_funct3, E_StoreSrc;
    wire                    E_Predict_Taken;
    wire [2:0]              E_GHSR;
    wire                    E_Mispredict;
    wire [31:0]             E_Correct_PC;
    wire                    E_data_req;
    wire                    E_Stall, E_Flush;
    wire [1:0]              ForwardAE, ForwardBE;

    wire                    E_amo;
    wire    [2:0]           E_amo_op;
    wire                    E_lr, E_sc;

    // ----------------------- MEM signals -----------------------
    wire [WIDTH_DATA-1:0]   M_ALUResult, M_WriteData, M_ImmExt;
    wire [WIDTH_ADDR-1:0]   M_PCPlus4, M_PCTarget, M_ResPC;
    wire [4:0]              M_rd;
    wire                    M_RegWrite, M_MemWrite, M_ResPCSel;
    wire [2:0]              M_ResultSrc, M_StoreSrc;
    wire                    M_data_req;
    wire                    M_Stall;

    // ----------------------- CACHE signals -----------------------
    wire [WIDTH_DATA-1:0]   C_Result, C_ImmExt, C_mux_result, C_ReadData;
    wire [WIDTH_ADDR-1:0]   C_ResPC;
    wire [4:0]              C_rd;
    wire                    C_RegWrite;
    wire [2:0]              C_ResultSrc;

    // ----------------------- WB signals -----------------------
    wire [WIDTH_DATA-1:0]   W_mux_result;
    wire [4:0]              W_rd;
    wire                    W_RegWrite;
    wire [2:0]              W_ResultSrc;
    

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

    HazardUnit HazardUnit_inst(
        .D_Rs1          (A1),
        .D_Rs2          (A2),
        .E_Rs1          (E_rs1),
        .E_Rs2          (E_rs2),
        .E_rd           (E_rd),
        .icache_stall   (icache_stall),
        .dcache_stall   (dcache_stall),
        .E_MulDivStall  (1'b0),
        .E_FPUStall     (1'b0),
        .raw_hazard     (raw_hazard),
        
        .E_ResultSrc    (E_ResultSrc),
        .E_RegSrc1      (1'b0),
        .E_RegSrc2      (1'b0),
        .E_Mispredict   (E_Mispredict),
        .M_RegWrite     (M_RegWrite),
        .M_FRegWrite    (1'b0),
        .C_RegWrite     (C_RegWrite),
        .C_FRegWrite    (1'b0),
        .M_Rd           (M_rd),
        .C_Rd           (C_rd),
        .W_Rd           (W_rd),
        .W_RegWrite     (W_RegWrite),
        .W_FRegWrite    (1'b0),
        
        .F_Stall            (F_Stall),
        .D_Stall            (D_Stall),
        .E_Stall            (E_Stall),
        .M_Stall            (M_Stall),
        .fetch_pipe_Flush   (fetch_pipe_Flush),
        .D_Flush            (D_Flush),
        .E_Flush            (E_Flush),
        .ForwardAE          (ForwardAE),
        .ForwardBE          (ForwardBE)
    );
    // ---------------------------------------- IF state ----------------------------------------
    PC #(
        .WIDTH      (WIDTH_ADDR), 
        .START_PC   (START_PC)
    ) PC_inst(    
        .clk    (clk),
        .rst_n  (rst_n),
        .EN     (F_Stall | test_stall),    // Khi stall hoac test_stall thi khong cap nhat PC
        .PCNext (PCNext),
        .PC     (F_PC)
    );

    // ---------------------------------------- CACHE CONNECTION ----------------------------------------
    assign icache_addr = F_PC;          // S1 -> Cache
    assign icache_req  = rst_n;         // luon yeu canh lenh khi khong reset
    assign F_RD        = imem_instr;    // S2 (Cache) -> 

    // ---------------------------------------- fetch_pipe REGISTER (IF -> S2) ----------------------------------------

    fetch_pipe fetch_pipe_register (
        .clk    (clk),
        .rst_n  (rst_n),
        .EN     (F_Stall | test_stall),
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
        .EN                 (D_Stall | test_stall),
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
    assign A1   = D_Instr[19:15];
    assign A2   = D_Instr[24:20];
    assign WD3  = D_Instr[11:7];
    
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
        .addr_addend_sel    (D_addr_addend_sel),
        .ResPCSel           (D_ResPCSel),
        .data_req           (D_data_req),
        .amo                (D_amo),
        .amo_op             (D_amo_op),
        .lr                 (D_lr),
        .sc                 (D_sc)
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

    Extend extend_inst(
        .ImmSrc (D_ImmSrc),
        .Instr  (D_Instr[31:0]),
        .ImmExt (D_ImmExt)
    );

    ID_EX ID_EX_register(
        .clk                (clk),
        .rst_n              (rst_n),
        .E_Flush            (E_Flush),
        .EN                 (E_Stall | test_stall),

        .D_RD1              (RDX1),
        .D_RD2              (RDX2),
        .D_Rs1              (A1),
        .D_Rs2              (A2),
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
        .D_addr_addend_sel  (D_addr_addend_sel),
        .D_ResPCSel         (D_ResPCSel),
        .D_Predict_Taken    (D_Predict_Taken),    
        .D_data_req         (D_data_req),  
        .D_amo              (D_amo),
        .D_amo_op           (D_amo_op),
        .D_lr               (D_lr),
        .D_sc               (D_sc),

        .E_RD1              (E_RD1),
        .E_RD2              (E_RD2),
        .E_Rs1              (E_rs1),
        .E_Rs2              (E_rs2),
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
        .E_addr_addend_sel  (E_addr_addend_sel),
        .E_ResPCSel         (E_ResPCSel),
        .E_Predict_Taken    (E_Predict_Taken),
        .E_data_req         (E_data_req),
        .E_amo              (E_amo),
        .E_amo_op           (E_amo_op),
        .E_lr               (E_lr),
        .E_sc               (E_sc)
    );

    // ---------------------------------------- Ex state ----------------------------------------
    ALU alu_inst(
        .ALUControl (E_ALUControl),
        .in1        (E_SrcA),
        .in2        (E_SrcB),

        .result     (E_ALUResult),
        .zero       (E_Zero),
        .signed_less(E_signed_less)
    );

    mux2_1 Mux_PCadd(
        .in0    (E_PC),
        .in1    (E_RD1),
        .sel    (E_addr_addend_sel),
        .res    (E_PCtmp)
    );

    mux4_1 mux_ForwardAE (
        .in0    (E_RD1),
        .in1    (M_ALUResult),
        .in2    (C_mux_result),
        .in3    (W_mux_result),
        .sel    (ForwardAE),
        .res    (E_SrcA)
    );

    mux4_1 mux_ForwardBE (
        .in0    (E_RD2),
        .in1    (M_ALUResult),
        .in2    (C_mux_result),
        .in3    (W_mux_result),
        .sel    (ForwardBE),
        .res    (E_WriteData)
    );

    mux2_1 mux_E_ALUSrc (
        .in0    (E_WriteData),
        .in1    (E_ImmExt),
        .sel    (E_ALUSrc),
        .res    (E_SrcB)
    );

    assign E_PCTarget   = E_ImmExt + E_PCtmp;

    EX_MEM EX_MEM_register(
        .clk    (clk),
        .rst_n  (rst_n),
        .EN     (M_Stall | test_stall),

        .E_ALUResult    (E_ALUResult),
        .E_WriteData    (E_WriteData),
        .E_ImmExt       (E_ImmExt),
        .E_PCPlus4      (E_PCPlus4),
        .E_PCTarget     (E_PCTarget),
        .E_rd           (E_rd),
        .E_RegWrite     (E_RegWrite),
        .E_MemWrite     (E_MemWrite),
        .E_ResultSrc    (E_ResultSrc),
        .E_StoreSrc     (E_StoreSrc),
        .E_ResPCSel     (E_ResPCSel),
        .E_data_req     (E_data_req),

        .M_ALUResult    (M_ALUResult),
        .M_WriteData    (M_WriteData),
        .M_ImmExt       (M_ImmExt),
        .M_PCPlus4      (M_PCPlus4),
        .M_PCTarget     (M_PCTarget),
        .M_rd           (M_rd),
        .M_RegWrite     (M_RegWrite),
        .M_MemWrite     (M_MemWrite),
        .M_ResultSrc    (M_ResultSrc),
        .M_StoreSrc     (M_StoreSrc),
        .M_ResPCSel     (M_ResPCSel),
        .M_data_req     (M_data_req)
    );

    // ---------------------------------------- DATA CACHE INTERFACE ----------------------------------------
    assign data_wr      = M_MemWrite;
    assign data_size    = M_StoreSrc;
    assign data_addr    = M_ALUResult;
    assign data_wdata   = M_WriteData;
    assign data_req     = M_data_req;

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
        .EN             (dcache_stall | test_stall),

        .M_Result       (M_ALUResult),
        .M_ImmExt       (M_ImmExt),
        .M_ResPC        (M_ResPC),
        .M_rd           (M_rd),
        .M_RegWrite     (M_RegWrite),
        .M_ResultSrc    (M_ResultSrc),

        .C_Result       (C_Result),
        .C_ImmExt       (C_ImmExt),
        .C_ResPC        (C_ResPC),
        .C_rd           (C_rd),
        .C_RegWrite     (C_RegWrite),
        .C_ResultSrc    (C_ResultSrc)
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

    // ---------------------------------------- [PIPELINE REGISTER] CACHE -> WRITEBACK ----------------------------------------

    MEM_WB MEM_WB_register(
        .clk            (clk),
        .rst_n          (rst_n),
        .M_rd           (C_rd),
        .M_RegWrite     (C_RegWrite),
        .M_ResultSrc    (C_ResultSrc),
        .C_mux_result   (C_mux_result),

        .W_rd           (W_rd),
        .W_RegWrite     (W_RegWrite),
        .W_ResultSrc    (W_ResultSrc),
        .W_mux_result   (W_mux_result)
    );
endmodule