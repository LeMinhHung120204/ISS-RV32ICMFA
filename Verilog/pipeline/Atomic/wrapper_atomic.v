`timescale 1ns / 1ps

module wrapper_atomic #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter STRB_WIDTH = 4,
    parameter NUM_CORES  = 4,
    parameter USE_LOCAL_ALU = 1  // 1: local ALU (portable), 0: ATOP (if memory supports)
) (
    input clk,
    input rstn,
    
    // CPU instruction interface
    input  [31:0]            cpu_instr,
    input                    cpu_instr_valid,
    output                   cpu_instr_ready,
    
    // CPU data interface
    input  [ID_WIDTH-1:0]    cpu_core_id,
    input  [ADDR_WIDTH-1:0]  cpu_rs1_data,    // Address operand (for LR/SC/AMO)
    input  [ADDR_WIDTH-1:0]  cpu_rs2_data,    // Value operand (for SC/AMO)
    
    // AXI Master - Read Address Channel
    output [ADDR_WIDTH-1:0]  m_axi_araddr,
    output [2:0]             m_axi_arprot,
    output [ID_WIDTH-1:0]    m_axi_arid,
    output                   m_axi_arlock,
    output                   m_axi_arvalid,
    input                    m_axi_arready,
    
    // AXI Master - Read Data Channel
    input  [DATA_WIDTH-1:0]  m_axi_rdata,
    input  [1:0]             m_axi_rresp,
    input  [ID_WIDTH-1:0]    m_axi_rid,
    input                    m_axi_rlast,
    input                    m_axi_rvalid,
    output                   m_axi_rready,
    
    // AXI Master - Write Address Channel
    output [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output [2:0]             m_axi_awprot,
    output [ID_WIDTH-1:0]    m_axi_awid,
    output [5:0]             m_axi_awatop,
    output                   m_axi_awlock,
    output                   m_axi_awvalid,
    input                    m_axi_awready,
    
    // AXI Master - Write Data Channel
    output [DATA_WIDTH-1:0]  m_axi_wdata,
    output [STRB_WIDTH-1:0]  m_axi_wstrb,
    output                   m_axi_wlast,
    output                   m_axi_wvalid,
    input                    m_axi_wready,
    
    // AXI Master - Write Response Channel
    input  [1:0]             m_axi_bresp,
    input  [ID_WIDTH-1:0]    m_axi_bid,
    input                    m_axi_blast,
    input                    m_axi_bvalid,
    output                   m_axi_bready,
    
    // ACE Master - Snoop Address Channel
    input  [ADDR_WIDTH-1:0]  m_axi_acaddr,
    input  [3:0]             m_axi_acsnoop,
    input                    m_axi_acvalid,
    output                   m_axi_acready,
    
    // ACE Master - Coherent Response Channel
    output [3:0]             m_axi_crresp,
    output                   m_axi_crvalid,
    input                    m_axi_crready,
    
    // ACE Master - Coherent Data Channel
    output [DATA_WIDTH-1:0]  m_axi_cddata,
    output                   m_axi_cdlast,
    output                   m_axi_cdvalid,
    input                    m_axi_cdready,
    
    // CPU result interface: Returns reserved data (LR), old value (AMO), or SC status
    output [DATA_WIDTH-1:0]  cpu_result,
    output                   cpu_result_valid,
    input                    cpu_result_ready,
    
    // Debug outputs
    output [3:0]             decoder_state,
    output [3:0]             atomic_state
);

    // Decoder output signals
    wire                 is_atomic_instr;
    wire                 is_lr_instr;
    wire                 is_sc_instr;
    wire                 is_amo_instr;
    wire [4:0]           funct5_instr;
    wire [4:0]           rs1_idx, rs2_idx, rd_idx;
    wire                 aq_bit, rl_bit;
    wire [5:0]           atop_signal;
    wire                 is_rv64;
    wire                 decoder_valid;
    wire [3:0]           decoder_error;
    
    wire                 internal_ar_ready;
    wire                 internal_aw_ready;
    wire                 internal_r_valid;
    wire                 internal_b_valid;

    // RISC-V Atomic Instruction Decoder
    // Parses LR.W, SC.W, AMOSWAP.W, AMOADD.W, etc.
    decode_atomic #(
        .INSTR_WIDTH(32),
        .ID_WIDTH(ID_WIDTH),
        .SUPPORT_RV64(0)
    ) decoder_inst (
        .instruction(cpu_instr),
        .core_id(cpu_core_id),
        .is_atomic(is_atomic_instr),
        .is_lr(is_lr_instr),
        .is_sc(is_sc_instr),
        .is_amo(is_amo_instr),
        .rs1(rs1_idx),
        .rs2(rs2_idx),
        .rd(rd_idx),
        .funct5(funct5_instr),
        .aq(aq_bit),
        .rl(rl_bit),
        .atop(atop_signal),
        .is_rv64(is_rv64),
        .is_valid_atomic(decoder_valid),
        .error_code(decoder_error)
    );

    // CPU can send new instruction when: unit is ready to accept AND instruction is valid atomic
    assign cpu_instr_ready = (internal_ar_ready || internal_aw_ready) && decoder_valid && is_atomic_instr;
    assign cpu_result_valid = internal_r_valid;

    // Atomic Execution Unit: Implements LR/SC and AMO operations
    // Handles per-core reservation state and multi-cycle read-modify-write
    unit_atomic #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .NUM_CORES(NUM_CORES),
        .USE_LOCAL_ALU(USE_LOCAL_ALU)
    ) atomic_unit_inst (
        .clk(clk),
        .rstn(rstn),
        
        // LR (Load-Reserved) read address: [3]=aq (acquire), [2]=rl (release), [1]=0, [0]=is_lr
        .cpu_ar_addr(cpu_rs1_data),
        .cpu_ar_prot(3'b010),
        .cpu_ar_id(cpu_core_id),
        .cpu_ar_user({aq_bit, rl_bit, 1'b0, is_lr_instr}),
        .cpu_ar_lock(1'b0),
        .cpu_ar_valid(is_lr_instr && cpu_instr_valid && decoder_valid),
        .cpu_ar_ready(internal_ar_ready),
        
        // Read data: Returns reservation token (LR), AMO old value, or SC status
        .cpu_r_data(cpu_result),
        .cpu_r_resp(),
        .cpu_r_id(),
        .cpu_r_last(),
        .cpu_r_valid(internal_r_valid),
        .cpu_r_ready(cpu_result_ready),
        
        // SC/AMO write address: [3]=aq, [2]=rl, [1]=is_sc (1=SC, 0=AMO), [0]=unused
        .cpu_aw_addr(cpu_rs1_data),
        .cpu_aw_prot(3'b010),
        .cpu_aw_id(cpu_core_id),
        .cpu_aw_atop(atop_signal),
        .cpu_aw_user({aq_bit, rl_bit, is_sc_instr, 1'b0}),
        .cpu_aw_lock(1'b0),
        .cpu_aw_valid((is_sc_instr || is_amo_instr) && cpu_instr_valid && decoder_valid),
        .cpu_aw_ready(internal_aw_ready),
        
        // Write data: Operand for SC (address validity) or AMO (rs2 value)
        .cpu_w_data(cpu_rs2_data),
        .cpu_w_strb(4'hF),
        .cpu_w_last(1'b1),
        .cpu_w_valid((is_sc_instr || is_amo_instr) && cpu_instr_valid && decoder_valid),
        .cpu_w_ready(),
        
        .cpu_b_resp(),
        .cpu_b_id(),
        .cpu_b_last(),
        .cpu_b_valid(internal_b_valid),
        .cpu_b_ready(cpu_result_ready),
        
        // Memory interface pass-through
        .mem_ar_addr(m_axi_araddr),
        .mem_ar_prot(m_axi_arprot),
        .mem_ar_id(m_axi_arid),
        .mem_ar_lock(m_axi_arlock),
        .mem_ar_valid(m_axi_arvalid),
        .mem_ar_ready(m_axi_arready),
        
        .mem_r_data(m_axi_rdata),
        .mem_r_resp(m_axi_rresp),
        .mem_r_id(m_axi_rid),
        .mem_r_last(m_axi_rlast),
        .mem_r_valid(m_axi_rvalid),
        .mem_r_ready(m_axi_rready),
        
        .mem_aw_addr(m_axi_awaddr),
        .mem_aw_prot(m_axi_awprot),
        .mem_aw_id(m_axi_awid),
        .mem_aw_atop(m_axi_awatop),
        .mem_aw_lock(m_axi_awlock),
        .mem_aw_valid(m_axi_awvalid),
        .mem_aw_ready(m_axi_awready),
        
        .mem_w_data(m_axi_wdata),
        .mem_w_strb(m_axi_wstrb),
        .mem_w_last(m_axi_wlast),
        .mem_w_valid(m_axi_wvalid),
        .mem_w_ready(m_axi_wready),
        
        .mem_b_resp(m_axi_bresp),
        .mem_b_id(m_axi_bid),
        .mem_b_last(m_axi_blast),
        .mem_b_valid(m_axi_bvalid),
        .mem_b_ready(m_axi_bready),
        
        // Snoop (cache coherency)
        .snoop_ac_addr(m_axi_acaddr),
        .snoop_ac_snoop(m_axi_acsnoop),
        .snoop_ac_valid(m_axi_acvalid),
        .snoop_ac_ready(m_axi_acready),
        
        .snoop_cr_resp(m_axi_crresp),
        .snoop_cr_valid(m_axi_crvalid),
        .snoop_cr_ready(m_axi_crready),
        
        .snoop_cd_data(m_axi_cddata),
        .snoop_cd_last(m_axi_cdlast),
        .snoop_cd_valid(m_axi_cdvalid),
        .snoop_cd_ready(m_axi_cdready)
    );

    // Debug state outputs
    assign decoder_state = {is_atomic_instr, is_lr_instr, is_sc_instr, is_amo_instr};
    assign atomic_state = {decoder_valid, decoder_error[2:0]};

endmodule
