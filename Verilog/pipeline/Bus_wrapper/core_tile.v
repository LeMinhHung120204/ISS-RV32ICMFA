`timescale 1ns/1ps

module core_tile #(
    parameter core_id = 0,
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input wire clk,
    input wire rst_n,

    // DATA CACHE INTERFACE (AXI4 Full + ACE)
    // AW Channel
    input  wire                m_d_axi_awready, 
    output wire [3:0]          m_d_axi_awid,
    output wire [ADDR_W-1:0]   m_d_axi_awaddr,
    output wire [7:0]          m_d_axi_awlen,
    output wire [2:0]          m_d_axi_awsize,
    output wire [1:0]          m_d_axi_awburst,
    output wire                m_d_axi_awvalid,
    // ACE Signals (Snoop cho D-Cache)
    output wire [2:0]          m_d_ace_awsnoop,
    output wire [1:0]          m_d_ace_awdomain,
    output wire [1:0]          m_d_ace_awbar,
    
    // W Channel
    input  wire                m_d_axi_wready,
    output wire [DATA_W-1:0]   m_d_axi_wdata,
    output wire [DATA_W/8-1:0] m_d_axi_wstrb,
    output wire                m_d_axi_wlast,
    output wire                m_d_axi_wvalid,

    // B Channel
    input  wire [3:0]          m_d_axi_bid,
    input  wire [1:0]          m_d_axi_bresp,
    input  wire                m_d_axi_bvalid,
    output wire                m_d_axi_bready,

    // AR Channel (Data Read)
    input  wire                m_d_axi_arready,
    output wire [3:0]          m_d_axi_arid,
    output wire [ADDR_W-1:0]   m_d_axi_araddr,
    output wire [7:0]          m_d_axi_arlen,
    output wire [2:0]          m_d_axi_arsize,
    output wire [1:0]          m_d_axi_arburst,
    output wire                m_d_axi_arvalid,
    // ACE Signals
    output wire [3:0]          m_d_ace_arsnoop,
    output wire [1:0]          m_d_ace_ardomain,
    output wire [1:0]          m_d_ace_arbar,

    // R Channel (Data Read Response)
    input  wire [3:0]          m_d_axi_rid,
    input  wire [DATA_W-1:0]   m_d_axi_rdata,
    input  wire [1:0]          m_d_axi_rresp,
    input  wire                m_d_axi_rlast,
    input  wire                m_d_axi_rvalid,
    output wire                m_d_axi_rready,

    // AC, CR, CD Channels (Snoop)
    // AC Channel
    input  wire                m_ace_acvalid,
    input  wire [ADDR_W-1:0]   m_ace_acaddr,
    input  wire [3:0]          m_ace_acsnoop,
    output wire                m_ace_acready,

    // CR Channel
    input  wire                m_ace_crready,
    output wire                m_ace_crvalid,
    output wire [4:0]          m_ace_crresp,

    // CD Channel
    input  wire                m_ace_cdready,
    output wire                m_ace_cdvalid,
    output wire [DATA_W-1:0]   m_ace_cddata,
    output wire                m_ace_cdlast,

    // INSTRUCTION CACHE INTERFACE (AXI4 Lite Read-Only)
    // AR Channel (Instruction Read)
    input  wire                m_i_axi_arready,
    output wire [3:0]          m_i_axi_arid,
    output wire [ADDR_W-1:0]   m_i_axi_araddr,
    output wire [7:0]          m_i_axi_arlen,
    output wire [2:0]          m_i_axi_arsize,
    output wire [1:0]          m_i_axi_arburst,
    output wire                m_i_axi_arvalid,

    // R Channel (Instruction Read Response)
    input  wire [3:0]          m_i_axi_rid,
    input  wire [DATA_W-1:0]   m_i_axi_rdata,
    input  wire [1:0]          m_i_axi_rresp,
    input  wire                m_i_axi_rlast,
    input  wire                m_i_axi_rvalid,
    output wire                m_i_axi_rready
);

    wire [DATA_W-1:0]   data_rdata;
    wire [DATA_W-1:0]   data_wdata;
    wire [ADDR_W-1:0]   data_addr;
    wire [1:0]          data_size;
    wire                data_req;
    wire                data_wr;
    wire                dcache_miss_stall;

    wire [DATA_W-1:0]   imem_instr;
    wire [ADDR_W-1:0]   icache_addr;
    wire                icache_req;
    wire                icache_miss_stall;

    dcache #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) u_dcache (
        .ACLK       (clk),
        .ARESETn    (rst_n),

         // CPU Interface
        .cpu_req    (data_req),
        .cpu_size   (data_size),
        .data_valid (1'b1),
        .cpu_we     (data_wr),
        .cpu_addr   (data_addr),
        .cpu_din    (data_wdata),
        .data_rdata (data_rdata),

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
        .oWID       (m_d_axi_wid),      // chưa biết như nào
        .oWDATA     (m_d_axi_wdata),
        .oWSTRB     (m_d_axi_wstrb),
        .oWLAST     (m_d_axi_wlast),
        .oWVALID    (m_d_axi_wvalid),

        // B Channel
        .iBID       (m_d_axi_bid),
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
        .iRID       (m_d_axi_rid),
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

    icache #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) u_icache (
        .ACLK       (clk),
        .ARESETn    (rst_n),

        // CPU Interface
        .cpu_req    (icache_req),
        .data_valid (1'b1),
        .cpu_addr   (icache_addr),
        .data_rdata (imem_instr),

        
        // CHỈ NỐI KÊNH READ (AR, R)
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
        .clk        (clk),
        .rst_n      (rst_n),

        // dcache Interface
        .data_rdata (data_rdata),
        .data_req   (data_req),
        .data_wr    (data_wr),
        .data_size  (data_size),
        .data_addr  (data_addr),
        .data_wdata (data_wdata),
        // .stall_i    (!dcache_valid_out), 

        // Icache Interface
        .imem_instr (imem_instr),
        .icache_req (icache_req),
        .icache_addr(icache_addr)
        // .stall_i    (!icache_valid_out) 

    );

endmodule