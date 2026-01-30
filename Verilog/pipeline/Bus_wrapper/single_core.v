`timescale 1ns / 1ps
module single_core #(
    parameter CORE_ID       = 1'b0,
    parameter ID_W          = 2,
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,

    // Cau hinh core
    parameter CODE_START     = 32'h0000_0000,
    parameter CODE_END       = 32'h0000_3FFF, 
    parameter DATA_START     = 32'h0000_4000,
    parameter DATA_END       = 32'h0000_7FFF,

    // Cau hinh cache
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter NUM_SETS_L2   = 32,
    parameter WORD_OFF_W    = 4, // 16 words
    parameter BYTE_OFF_W    = 2,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32,
    parameter STRB_W        = CACHE_DATA_W/8
)(
    input   ACLK,
    input   ARESETn,
    input   test_stall,

    // AXI ACE <-> Cache L3    
    // --- Write Address Channel (AW) ---
    output  [ID_W-1:0]      m_axi_awid,
    output  [ADDR_W-1:0]    m_axi_awaddr,
    output  [7:0]           m_axi_awlen,
    output  [2:0]           m_axi_awsize,
    output  [1:0]           m_axi_awburst,
    output                  m_axi_awvalid,
    input                   m_axi_awready,
    // ACE Signals
    output  [2:0]           m_axi_awsnoop,
    output  [1:0]           m_axi_awdomain,
    
    // --- Write Data Channel (W) ---
    output  [DATA_W-1:0]        m_axi_wdata,
    output  [STRB_W-1:0]        m_axi_wstrb,
    output                      m_axi_wlast,
    output                      m_axi_wvalid,
    input                       m_axi_wready,
    
    // --- Write Response Channel (B) ---
    input   [ID_W-1:0]      m_axi_bid,
    input   [1:0]           m_axi_bresp,
    input                   m_axi_bvalid,
    output                  m_axi_bready,

    // --- Read Address Channel (AR) ---
    output  [ID_W-1:0]      m_axi_arid,
    output  [ADDR_W-1:0]    m_axi_araddr,
    output  [7:0]           m_axi_arlen,
    output  [2:0]           m_axi_arsize,
    output  [1:0]           m_axi_arburst,
    output                  m_axi_arvalid,
    input                   m_axi_arready,
    // ACE Signals
    output  [3:0]           m_axi_arsnoop,
    output  [1:0]           m_axi_ardomain,

    // --- Read Data Channel (R) ---
    input   [ID_W-1:0]          m_axi_rid,
    input   [DATA_W-1:0]        m_axi_rdata,
    input   [3:0]               m_axi_rresp,
    input                       m_axi_rlast,
    input                       m_axi_rvalid,
    output                      m_axi_rready,

    // --- Snoop Address Channel (AC - Input from L3) ---
    input                   s_ace_acvalid,
    input   [ADDR_W-1:0]    s_ace_acaddr,
    input   [3:0]           s_ace_acsnoop,
    output                  s_ace_acready,

    // --- Snoop Response Channel (CR - Output to L3) ---
    input                   s_ace_crready,
    output                  s_ace_crvalid,
    output  [4:0]           s_ace_crresp,
    
    // --- Snoop Data Channel (CD - Output to L3) ---
    input                       s_ace_cdready,
    output                      s_ace_cdvalid,
    output  [DATA_W-1:0]        s_ace_cddata,
    output                      s_ace_cdlast
);

    // ---------------------------------------- INTERNAL WIRES ----------------------------------------
    // CPU <-> L1
    wire [DATA_W-1:0]   data_rdata, data_wdata;
    wire [ADDR_W-1:0]   data_addr;
    wire [1:0]          data_size;
    wire                data_req, data_wr, dcache_stall, raw_hazard;

    wire [DATA_W-1:0]   imem_instr;
    wire [ADDR_W-1:0]   icache_addr;
    wire                icache_req, icache_flush, icache_stall;

    // L1 <-> Arbiter <-> L2 Wires
    wire                l1i_req_valid, l1i_req_ready, l1i_rdata_valid;
    wire [ADDR_W-1:0]   l1i_req_addr;
    
    wire                l1d_req_valid, l1d_req_ready;
    wire [1:0]          l1d_req_cmd;
    wire [ADDR_W-1:0]   l1d_req_addr;
    wire                l1d_wdata_valid, l1d_wdata_ready;
    wire [CACHE_DATA_W-1:0]   l1d_wdata;
    wire                l1d_rdata_valid;

    // Arbiter to L2
    wire                l2_req_valid, l2_req_ready;
    wire [1:0]          l2_req_cmd;
    wire [ADDR_W-1:0]   l2_req_addr;
    wire [CACHE_DATA_W-1:0]   l2_wdata;       
    wire                l2_wdata_valid, l2_wdata_ready;
    wire [CACHE_DATA_W-1:0]   l2_rdata;       
    wire                l2_rdata_valid, l2_rdata_ready;

    // Internal Snoop (L2 -> L1 D-Cache)
    wire                int_snoop_valid;
    wire [ADDR_W-1:0]   int_snoop_addr;
    wire [1:0]          int_snoop_type;
    wire                int_snoop_hit;
    wire                int_snoop_dirty;
    wire [CACHE_DATA_W-1:0]   int_snoop_data;

    // ---------------------------------------- MODULE INSTANTIATIONS ----------------------------------------
    RV32IA #( 
        .WIDTH_ADDR (ADDR_W), 
        .WIDTH_DATA (DATA_W),
        .START_PC   (CODE_START)
        // .END_PC     ()
    ) u_RV32IA (
        .clk            (ACLK), 
        .rst_n          (ARESETn),
        .test_stall     (test_stall),

        .data_rdata     (data_rdata), 
        .data_req       (data_req), 
        .data_wr        (data_wr),
        .data_size      (data_size), 
        .data_addr      (data_addr), 
        .data_wdata     (data_wdata),
        .dcache_stall   (dcache_stall),
        .raw_hazard     (raw_hazard),

        .imem_instr     (imem_instr), 
        .icache_req     (icache_req),
        .icache_flush   (icache_flush), 
        .icache_addr    (icache_addr),
        .icache_stall   (icache_stall)
    );

    // ---------------------------------------- I-CACHE (L1) ----------------------------------------
    icache #( 
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W),

        // cau hinh cache
        .NUM_WAYS   (NUM_WAYS),
        .NUM_SETS   (NUM_SETS),
        .WORD_OFF_W (WORD_OFF_W),
        .BYTE_OFF_W (BYTE_OFF_W)
    ) u_icache_L1 (
        .clk        (ACLK), 
        .rst_n      (ARESETn),
        .cpu_req        (icache_req), 
        .cpu_addr       (icache_addr), 
        .icache_flush   (icache_flush),

        .dcache_stall   (dcache_stall), 
        .raw_hazard     (raw_hazard),
        
        .pipeline_stall (icache_stall),
        .data_rdata     (imem_instr),
        
        .i_l2_req_ready     (l1i_req_ready), 
        .o_l2_req_valid     (l1i_req_valid), 
        .o_l2_req_addr      (l1i_req_addr),
        .i_l2_rdata_valid   (l1i_rdata_valid), 
        .i_l2_rdata         (l2_rdata), 
        .o_l2_rdata_ready   ()
    );

    // ---------------------------------------- D-CACHE (L1) ----------------------------------------
    dcache #( 
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W),

        // cau hinh cache
        .NUM_WAYS   (NUM_WAYS),
        .NUM_SETS   (NUM_SETS),
        .WORD_OFF_W (WORD_OFF_W),
        .BYTE_OFF_W (BYTE_OFF_W)
    ) u_dcache_L1 (
        .clk            (ACLK), 
        .rst_n          (ARESETn),
        .cpu_req            (data_req), 
        .cpu_we             (data_wr), 
        .cpu_addr           (data_addr),
        .cpu_din            (data_wdata), 
        .cpu_size           (data_size), 
        .data_rdata         (data_rdata),
        .pipeline_stall     (dcache_stall),
        .raw_hazard         (raw_hazard),

        .i_l2_req_ready     (l1d_req_ready), 
        .o_l2_req_valid     (l1d_req_valid),
        .o_l2_req_cmd       (l1d_req_cmd), 
        .o_l2_req_addr      (l1d_req_addr),

        .i_l2_wdata_ready   (l1d_wdata_ready), 
        .o_l2_wdata         (l1d_wdata),
        .o_l2_wdata_valid   (l1d_wdata_valid), 
        
        .i_l2_rdata_valid   (l1d_rdata_valid), 
        .i_l2_rdata         (l2_rdata), 
        .o_l2_rdata_ready   (),

        // Internal Snoop Port
        .i_snoop_valid      (int_snoop_valid), 
        .i_snoop_addr       (int_snoop_addr),
        .i_snoop_type       (int_snoop_type),
        .o_snoop_hit        (int_snoop_hit), 
        .o_snoop_dirty      (int_snoop_dirty),        
        .o_snoop_data       (int_snoop_data)
    );

    // ---------------------------------------- ARBITER ----------------------------------------
    arbiter #( 
        .ADDR_W     (ADDR_W),
        .CODE_START (CODE_START),
        .DATA_START (DATA_START)
    ) u_l2_arbiter (
        .clk        (ACLK), 
        .rst_n      (ARESETn),
        .i_c0_req_valid     (l1i_req_valid), 
        .i_c0_req_addr      (l1i_req_addr), 
        .o_c0_req_ready     (l1i_req_ready),
        
        .i_c1_req_valid     (l1d_req_valid), 
        .i_c1_req_cmd       (l1d_req_cmd), 
        .i_c1_req_addr      (l1d_req_addr), 
        .o_c1_req_ready     (l1d_req_ready),
        
        .i_l2_ready         (l2_req_ready), 
        .o_l2_valid         (l2_req_valid), 
        .o_l2_cmd           (l2_req_cmd), 
        .o_l2_addr          (l2_req_addr)
    );

    assign l2_wdata         = l1d_wdata;
    assign l2_wdata_valid   = l1d_wdata_valid;
    assign l1d_wdata_ready  = l2_wdata_ready; 

    assign l1d_rdata_valid  = l2_rdata_valid;
    assign l1i_rdata_valid  = l2_rdata_valid;

    // ---------------------------------------- L2 CACHE (The Wrapper) ----------------------------------------
    L2_cache #( 
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W),
        .ID_W       (ID_W),
        .CORE_ID    (CORE_ID),

        // cau hinh cache
        // cau hinh cache
        .NUM_WAYS   (NUM_WAYS),
        .NUM_SETS   (NUM_SETS_L2),
        .WORD_OFF_W (WORD_OFF_W),
        .BYTE_OFF_W (BYTE_OFF_W)
    ) u_l2_cache (
        .ACLK       (ACLK), 
        .ARESETn    (ARESETn),

        // --- INTERNAL INTERFACE (-> L1) ---
        // Request (Command/Address)
        .i_req_valid    (l2_req_valid),
        .i_req_cmd      (l2_req_cmd),
        .i_req_addr     (l2_req_addr),
        .o_req_ready    (l2_req_ready),
        
        // Write Data (Data from L1 writeback)
        .i_wdata        (l2_wdata),
        .i_wdata_valid  (l2_wdata_valid),
        .o_wdata_ready  (l2_wdata_ready),

        // Read Data (Data to L1 refill)
        .o_rdata        (l2_rdata),
        .o_rdata_valid  (l2_rdata_valid),
        .i_rdata_ready  (1'b1),             // tam de vay

        // Internal Snoop Forwarding
        .o_int_snoop_valid  (int_snoop_valid),
        .o_int_snoop_addr   (int_snoop_addr),
        .o_int_snoop_type   (int_snoop_type),
        .i_int_snoop_hit    (int_snoop_hit),
        .i_int_snoop_dirty  (int_snoop_dirty),
        .i_int_snoop_data   (int_snoop_data),

        // --- AXI ACE ---
        // AW Channel
        .iAWREADY   (m_axi_awready),
        .oAWID      (m_axi_awid),
        .oAWADDR    (m_axi_awaddr),
        .oAWLEN     (m_axi_awlen),
        .oAWSIZE    (m_axi_awsize),
        .oAWBURST   (m_axi_awburst),
        .oAWVALID   (m_axi_awvalid),
        .oAWSNOOP   (m_axi_awsnoop),
        .oAWDOMAIN  (m_axi_awdomain),

        // W Channel
        .iWREADY    (m_axi_wready),
        .oWDATA     (m_axi_wdata),
        .oWSTRB     (m_axi_wstrb),
        .oWLAST     (m_axi_wlast),
        .oWVALID    (m_axi_wvalid),
        
        // B Channel
        .iBID       (m_axi_bid),
        .iBRESP     (m_axi_bresp),
        .iBVALID    (m_axi_bvalid),
        .oBREADY    (m_axi_bready),

        // AR Channel
        .iARREADY   (m_axi_arready),
        .oARID      (m_axi_arid),
        .oARADDR    (m_axi_araddr),
        .oARLEN     (m_axi_arlen),
        .oARSIZE    (m_axi_arsize),
        .oARBURST   (m_axi_arburst),
        .oARVALID   (m_axi_arvalid),
        .oARSNOOP   (m_axi_arsnoop),
        .oARDOMAIN  (m_axi_ardomain),

        // R Channel
        .iRID       (m_axi_rid),
        .iRDATA     (m_axi_rdata),
        .iRRESP     (m_axi_rresp),
        .iRLAST     (m_axi_rlast),
        .iRVALID    (m_axi_rvalid),
        .oRREADY    (m_axi_rready),

        // Snoop Channels (AC, CR, CD)
        .iACVALID   (s_ace_acvalid),
        .iACADDR    (s_ace_acaddr),
        .iACSNOOP   (s_ace_acsnoop),
        .oACREADY   (s_ace_acready),        

        .iCRREADY   (s_ace_crready),
        .oCRVALID   (s_ace_crvalid),
        .oCRRESP    (s_ace_crresp),

        .iCDREADY   (s_ace_cdready),
        .oCDVALID   (s_ace_cdvalid),
        .oCDDATA    (s_ace_cddata),
        .oCDLAST    (s_ace_cdlast)
    );

endmodule