`timescale 1ns/1ps
module core_tile #(
    parameter CORE_ID   = 1'b0,
    parameter ID_W      = 2,
    parameter ADDR_W    = 32,
    parameter DATA_W    = 32
)(
    input   ACLK,
    input   ARESETn,

    // DATA CACHE INTERFACE (AXI4 Full + ACE)
    // AW Channel
    input                   m_d_axi_awready, 
    output  [ID_W-1:0]      m_d_axi_awid,
    output  [ADDR_W-1:0]    m_d_axi_awaddr,
    output  [7:0]           m_d_axi_awlen,
    output  [2:0]           m_d_axi_awsize,
    output  [1:0]           m_d_axi_awburst,
    output                  m_d_axi_awvalid,
    // ACE Signals (Snoop cho D-Cache)
    output  [2:0]   m_d_ace_awsnoop,
    output  [1:0]   m_d_ace_awdomain,
    output  [1:0]   m_d_ace_awbar,
    
    // W Channel
    input                   m_d_axi_wready,
    output  [ID_W-1:0]      m_d_axi_wid,
    output  [DATA_W-1:0]    m_d_axi_wdata,
    output  [DATA_W/8-1:0]  m_d_axi_wstrb,
    output                  m_d_axi_wlast,
    output                  m_d_axi_wvalid,

    // B Channel
    input   [ID_W-1:0]  m_d_axi_bid,
    input   [1:0]       m_d_axi_bresp,
    input               m_d_axi_bvalid,
    output              m_d_axi_bready,

    // AR Channel (Data Read)
    input                   m_d_axi_arready,
    output  [ID_W-1:0]      m_d_axi_arid,
    output  [ADDR_W-1:0]    m_d_axi_araddr,
    output  [7:0]           m_d_axi_arlen,
    output  [2:0]           m_d_axi_arsize,
    output  [1:0]           m_d_axi_arburst,
    output                  m_d_axi_arvalid,
    // ACE Signals
    output  [3:0]   m_d_ace_arsnoop,
    output  [1:0]   m_d_ace_ardomain,
    output  [1:0]   m_d_ace_arbar,

    // R Channel (Data Read Response)
    input   [ID_W-1:0]      m_d_axi_rid,
    input   [DATA_W-1:0]    m_d_axi_rdata,
    input   [3:0]           m_d_axi_rresp,
    input                   m_d_axi_rlast,
    input                   m_d_axi_rvalid,
    output                  m_d_axi_rready,

    // AC, CR, CD Channels (Snoop)
    // AC Channel
    input                   m_ace_acvalid,
    input   [ADDR_W-1:0]    m_ace_acaddr,
    input   [3:0]           m_ace_acsnoop,
    output                  m_ace_acready,

    // CR Channel
    input               m_ace_crready,
    output              m_ace_crvalid,
    output  [4:0]       m_ace_crresp,

    // CD Channel
    input                   m_ace_cdready,
    output                  m_ace_cdvalid,
    output  [DATA_W-1:0]    m_ace_cddata,
    output                  m_ace_cdlast,

    // INSTRUCTION CACHE INTERFACE (AXI4 Lite Read-Only)
    // AR Channel (Instruction Read)
    input                   m_i_axi_arready,
    output  [ID_W-1:0]      m_i_axi_arid,
    output  [ADDR_W-1:0]    m_i_axi_araddr,
    output  [7:0]           m_i_axi_arlen,
    output  [2:0]           m_i_axi_arsize,
    output  [1:0]           m_i_axi_arburst,
    output                  m_i_axi_arvalid,

    // R Channel (Instruction Read Response)
    input   [ID_W-1:0]      m_i_axi_rid,
    input   [DATA_W-1:0]    m_i_axi_rdata,
    input   [1:0]           m_i_axi_rresp,
    input                   m_i_axi_rlast,
    input                   m_i_axi_rvalid,
    output                  m_i_axi_rready
);

    wire [DATA_W-1:0]   data_rdata;
    wire [DATA_W-1:0]   data_wdata;
    wire [ADDR_W-1:0]   data_addr;
    wire [1:0]          data_size;
    wire                data_req;
    wire                data_wr;
    wire                dcache_stall;

    wire [DATA_W-1:0]   imem_instr;
    wire [ADDR_W-1:0]   icache_addr;
    wire                icache_req;
    wire                icache_flush;          
    wire                icache_stall;

    /*
    icache: ID = 2'b0x 
    dcache: ID = 2'b1x
    core0:  ID = 2'bx0
    core1:  ID = 2'bx1
    */

    dcache_v2 #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .CORE_ID(CORE_ID)
    ) u_dcache (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),

         // CPU Interface
        .cpu_req    (data_req),
        .cpu_size   (data_size),
        // .data_valid (1'b1),
        .cpu_we     (data_wr),
        .cpu_addr   (data_addr),
        .cpu_din    (data_wdata),
        .data_rdata (data_rdata),
        .pipeline_stall (dcache_stall),

        // AW Channel
        .iAWREADY   (m_d_axi_awready),
        .oAWID      (m_d_axi_awid),     // chưa biết như nào
        .oAWADDR    (m_d_axi_awaddr),
        .oAWLEN     (m_d_axi_awlen),
        .oAWSIZE    (m_d_axi_awsize),
        .oAWBURST   (m_d_axi_awburst),
        .oAWVALID   (m_d_axi_awvalid),
        
        // W Channel
        .iWREADY    (m_d_axi_wready),
        .oWDATA     (m_d_axi_wdata),
        .oWSTRB     (m_d_axi_wstrb),
        .oWLAST     (m_d_axi_wlast),
        .oWVALID    (m_d_axi_wvalid),

        // B Channel
        .iBID       (m_d_axi_bid),      // chưa biết như nào
        .iBRESP     (m_d_axi_bresp),
        .iBVALID    (m_d_axi_bvalid),
        .oBREADY    (m_d_axi_bready),

        // AR Channel
        .iARREADY   (m_d_axi_arready),
        .oARID      (m_d_axi_arid),     // chưa biết như nào
        .oARADDR    (m_d_axi_araddr),
        .oARLEN     (m_d_axi_arlen),
        .oARSIZE    (m_d_axi_arsize),
        .oARBURST   (m_d_axi_arburst),
        .oARVALID   (m_d_axi_arvalid),

        // R Channel
        .iRID       (m_d_axi_rid),      // // chưa biết như nào
        .iRDATA     (m_d_axi_rdata),
        .iRRESP     (m_d_axi_rresp),
        .iRLAST     (m_d_axi_rlast),
        .iRVALID    (m_d_axi_rvalid),
        .oRREADY    (m_d_axi_rready),
        
        // ACE Signals
        .oAWSNOOP   (m_d_ace_awsnoop),
        .oAWDOMAIN  (m_d_ace_awdomain),
        .oAWBAR     (m_d_ace_awbar),
        .oARSNOOP   (m_d_ace_arsnoop),
        .oARDOMAIN  (m_d_ace_ardomain),
        .oARBAR     (m_d_ace_arbar),
        
        // Snoop Channels (AC, CR, CD)
        // AC Channel
        .iACVALID   (m_ace_acvalid),
        .iACADDR    (m_ace_acaddr),
        .iACSNOOP   (m_ace_acsnoop),
        .oACREADY   (m_ace_acready),

        // CR Channel
        .iCRREADY   (m_ace_crready),
        .oCRVALID   (m_ace_crvalid),
        .oCRRESP    (m_ace_crresp),

        // CD Channel
        .iCDREADY   (m_ace_cdready),
        .oCDVALID   (m_ace_cdvalid), 
        .oCDDATA    (m_ace_cddata),
        .oCDLAST    (m_ace_cdlast)
    );

    icache_v2 #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .CORE_ID(CORE_ID)
    ) u_icache (
        .ACLK       (ACLK),
        .ARESETn    (ARESETn),

        // CPU Interface
        .cpu_req        (icache_req),
        .cpu_addr       (icache_addr),
        .data_rdata     (imem_instr),
        .pipeline_stall (icache_stall),
        .icache_flush   (icache_flush),

        .dcache_stall   (dcache_stall),

        // AR Channel
        .iARREADY   (m_i_axi_arready),
        .oARID      (m_i_axi_arid),    // chưa biết như nào
        .oARADDR    (m_i_axi_araddr),
        .oARLEN     (m_i_axi_arlen),
        .oARSIZE    (m_i_axi_arsize),
        .oARBURST   (m_i_axi_arburst),
        .oARVALID   (m_i_axi_arvalid),

        // R Channel
        .iRID       (m_i_axi_rid),
        .iRDATA     (m_i_axi_rdata),
        .iRRESP     (m_i_axi_rresp),
        .iRLAST     (m_i_axi_rlast),
        .iRVALID    (m_i_axi_rvalid),
        .oRREADY    (m_i_axi_rready)
    );

    RV32IMF #(
        .WIDTH_ADDR (32),
        .WIDTH_DATA (32)
    ) u_RV32IMF (
        .clk            (ACLK),
        .rst_n          (ARESETn),

        // dcache Interface
        .data_rdata     (data_rdata),
        .data_req       (data_req),
        .data_wr        (data_wr),
        .data_size      (data_size),
        .data_addr      (data_addr),
        .data_wdata     (data_wdata),
        .dcache_stall   (dcache_stall),
        
        // Icache Interface
        .imem_instr     (imem_instr),
        .icache_req     (icache_req),
        .icache_flush   (icache_flush),
        .icache_addr    (icache_addr),
        .icache_stall   (icache_stall)
    );

endmodule