`timescale 1ns / 1ps

module wrapper_atomic #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter STRB_WIDTH = 4,
    parameter NUM_CORES  = 2
) (
    input clk,
    input rstn,
    
    // CPU Interface (instruction + data)
    input  [31:0]            cpu_instr,
    input                    cpu_instr_valid,
    output                   cpu_instr_ready,
    
    input  [31:0]            cpu_data_in,
    input  [ID_WIDTH-1:0]    cpu_core_id,
    input  [ADDR_WIDTH-1:0]  cpu_rs1_data,
    input  [ADDR_WIDTH-1:0]  cpu_rs2_data,
    
    // AXI ACE Master Interface
    // Read Address Channel
    output [ADDR_WIDTH-1:0]  m_axi_araddr,
    output [2:0]             m_axi_arprot,
    output [ID_WIDTH-1:0]    m_axi_arid,
    output                   m_axi_arlock,
    output                   m_axi_arvalid,
    input                    m_axi_arready,
    
    // Read Data Channel
    input  [DATA_WIDTH-1:0]  m_axi_rdata,
    input  [1:0]             m_axi_rresp,
    input  [ID_WIDTH-1:0]    m_axi_rid,
    input                    m_axi_rlast,
    input                    m_axi_rvalid,
    output                   m_axi_rready,
    
    // Write Address Channel
    output [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output [2:0]             m_axi_awprot,
    output [ID_WIDTH-1:0]    m_axi_awid,
    output [5:0]             m_axi_awatop,
    output                   m_axi_awlock,
    output                   m_axi_awvalid,
    input                    m_axi_awready,
    
    // Write Data Channel
    output [DATA_WIDTH-1:0]  m_axi_wdata,
    output [STRB_WIDTH-1:0]  m_axi_wstrb,
    output                   m_axi_wlast,
    output                   m_axi_wvalid,
    input                    m_axi_wready,
    
    // Write Response Channel
    input  [1:0]             m_axi_bresp,
    input  [ID_WIDTH-1:0]    m_axi_bid,
    input                    m_axi_blast,
    input                    m_axi_bvalid,
    output                   m_axi_bready,
    
    // Snoop Address Channel
    input  [ADDR_WIDTH-1:0]  m_axi_acaddr,
    input  [3:0]             m_axi_acsnoop,
    input                    m_axi_acvalid,
    output                   m_axi_acready,
    
    // Snoop Response Channel
    output [3:0]             m_axi_crresp,
    output                   m_axi_crvalid,
    input                    m_axi_crready,
    
    // Snoop Data Channel
    output [DATA_WIDTH-1:0]  m_axi_cddata,
    output                   m_axi_cdlast,
    output                   m_axi_cdvalid,
    input                    m_axi_cdready,
    
    // CPU Response
    output [DATA_WIDTH-1:0]  cpu_result,
    output                   cpu_result_valid,
    input                    cpu_result_ready,
    
    // Status/Debug
    output [3:0]             decoder_state,
    output [3:0]             amo_state
);

    // Internal signals
    wire [31:0]          decoded_instr;
    wire                 is_atomic_instr;
    wire                 is_lr_instr;
    wire                 is_sc_instr;
    wire                 is_amo_instr;
    wire [4:0]           funct5_instr;
    wire [4:0]           rs1_idx, rs2_idx, rd_idx;
    wire                 aq_bit, rl_bit;
    wire [5:0]           atop_signal;
    wire                 decoder_valid;
    wire [3:0]           decoder_error;
    
    wire [ADDR_WIDTH-1:0] atomic_addr;
    wire [DATA_WIDTH-1:0] atomic_operand;
    wire [5:0]            atomic_atop;
    wire [2:0]            atomic_user;
    wire                  atomic_valid;
    wire                  atomic_ready;

    // ===== INSTRUCTION DECODER =====
    decode_atomic #(
        .INSTR_WIDTH(32),
        .ID_WIDTH(ID_WIDTH)
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
        .is_valid_atomic(decoder_valid),
        .error_code(decoder_error)
    );

    wire                  internal_ar_ready;
    wire                  internal_aw_ready;
    wire                  internal_r_valid;
    wire                  internal_b_valid;
    
    assign cpu_instr_ready = internal_ar_ready | internal_aw_ready;
    assign cpu_result_valid = internal_r_valid | internal_b_valid;

    // ===== ATOMIC EXECUTION UNIT =====
    unit_atomic #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .NUM_CORES(NUM_CORES)
    ) atomic_unit_inst (
        .clk(clk),
        .rstn(rstn),
        
        // CPU Interface
        .cpu_ar_addr(cpu_rs1_data),
        .cpu_ar_prot(3'b010),
        .cpu_ar_id(cpu_core_id),
        .cpu_ar_user({2'b00, is_lr_instr}),
        .cpu_ar_lock(1'b0),
        .cpu_ar_valid(is_lr_instr && cpu_instr_valid && decoder_valid),
        .cpu_ar_ready(internal_ar_ready),
        
        .cpu_r_data(cpu_result),
        .cpu_r_resp(),
        .cpu_r_id(),
        .cpu_r_last(),
        .cpu_r_valid(internal_r_valid),
        .cpu_r_ready(cpu_result_ready),
        
        .cpu_aw_addr(cpu_rs1_data),
        .cpu_aw_prot(3'b010),
        .cpu_aw_id(cpu_core_id),
        .cpu_aw_atop(atop_signal),
        .cpu_aw_user({2'b00, is_sc_instr}),
        .cpu_aw_lock(1'b0),
        .cpu_aw_valid((is_sc_instr || is_amo_instr) && cpu_instr_valid && decoder_valid),
        .cpu_aw_ready(internal_aw_ready),
        
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
        
        // AXI Memory Interface
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
        
        // Snoop Channels
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

    // Debug signals
    assign decoder_state = {is_atomic_instr, is_lr_instr, is_sc_instr, is_amo_instr};
    assign amo_state = {decoder_valid, decoder_error[2:0]};



endmodule
