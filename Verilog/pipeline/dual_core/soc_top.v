`timescale 1ns/1ps

module soc_top #(
    // Cau hinh core
    parameter C0_START_PC   = 32'd0,
    parameter C0_END_PC     = 32'd1024,

    parameter C1_START_PC   = 32'd1024,
    parameter C1_END_PC     = 32'd2048,

    // Cau hinh cache
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter NUM_SETS_L2   = 32,
    parameter NUM_SETS_L3   = 64,
    parameter WORD_OFF_W    = 4, // 16 words
    parameter BYTE_OFF_W    = 2
)(
    input ACLK, ARESETn,

    // EXTERNAL MEMORY AXI4 MASTER INTERFACE (to external memory)
    output [1:0]    m_axi_awid,
    output [31:0]   m_axi_awaddr,
    output [7:0]    m_axi_awlen,
    output [2:0]    m_axi_awsize,
    output [1:0]    m_axi_awburst,
    output          m_axi_awvalid,
    input           m_axi_awready,

    output [511:0]  m_axi_wdata,
    output [63:0]   m_axi_wstrb,
    output          m_axi_wlast,
    output          m_axi_wvalid,
    input           m_axi_wready,

    input  [1:0]    m_axi_bid,
    input  [1:0]    m_axi_bresp,
    input           m_axi_bvalid,
    output          m_axi_bready,

    output [1:0]    m_axi_arid,
    output [31:0]   m_axi_araddr,
    output [7:0]    m_axi_arlen,
    output [2:0]    m_axi_arsize,
    output [1:0]    m_axi_arburst,
    output          m_axi_arvalid,
    input           m_axi_arready,

    input  [1:0]    m_axi_rid,
    input  [511:0]  m_axi_rdata,
    input  [1:0]    m_axi_rresp,
    input           m_axi_rlast,
    input           m_axi_rvalid,
    output          m_axi_rready
);
    // INTERNAL WIRES
    // ------------------- CORE A INTERFACE -------------------
    wire [31:0]  c0_araddr;
    wire [3:0]   c0_arsnoop;
    wire         c0_arvalid, c0_arready;
    wire [511:0] c0_rdata;
    wire         c0_rvalid, c0_rlast, c0_rready;
    wire [31:0]  c0_acaddr;
    wire [3:0]   c0_acsnoop;
    wire         c0_acvalid, c0_acready;
    wire         c0_crvalid;
    wire [4:0]   c0_crresp;
    wire         c0_crready = 1'b1; 
    wire [511:0] c0_cddata;
    wire         c0_cdvalid, c0_cdlast;
    wire         c0_cdready = 1'b1; 

    // Write channel wires for core0
    wire [31:0]  c0_awaddr;
    wire         c0_awvalid, c0_awready;
    wire [511:0] c0_wdata;
    wire         c0_wvalid, c0_wready;
    wire         c0_bvalid;
    wire [1:0]   c0_bresp;
    wire         c0_bready;

    // ------------------- CORE B INTERFACE -------------------
    wire [31:0]  c1_araddr;
    wire [3:0]   c1_arsnoop;
    wire         c1_arvalid, c1_arready;
    wire [511:0] c1_rdata;
    wire         c1_rvalid, c1_rlast, c1_rready;
    wire [31:0]  c1_acaddr;
    wire [3:0]   c1_acsnoop;
    wire         c1_acvalid, c1_acready;
    wire         c1_crvalid;
    wire [4:0]   c1_crresp;
    wire         c1_crready = 1'b1;
    wire [511:0] c1_cddata;
    wire         c1_cdvalid, c1_cdlast;
    wire         c1_cdready = 1'b1; 

    // Write channel wires for core1
    wire [31:0]  c1_awaddr;
    wire         c1_awvalid, c1_awready;
    wire [511:0] c1_wdata;
    wire         c1_wvalid, c1_wready;
    wire         c1_bvalid;
    wire [1:0]   c1_bresp;
    wire         c1_bready;

    // --- L3 bridge wires (connect interconnect <-> top-level external AXI fields)
    // These provide the small native L3 interface that `ace_interconnect` drives;
    // `soc_top` then expands them into full AXI4 fields (ID/LEN/SIZE/BURST, etc.).
    wire [31:0]  l3_araddr;
    wire         l3_arvalid, l3_arready;
    wire [511:0] l3_rdata;
    wire         l3_rvalid, l3_rlast, l3_rready;

    wire [31:0]  l3_awaddr;
    wire         l3_awvalid, l3_awready;
    wire [511:0] l3_wdata;
    wire         l3_wvalid, l3_wready;
    wire         l3_bvalid;
    wire [1:0]   l3_bresp;
    wire         l3_bready;


    // ------------------- INSTANTIATE CORE A (ID = 0) -------------------
    single_core #( 
        .CORE_ID        (0),
        .NUM_WAYS       (NUM_WAYS  ),
        .NUM_SETS       (NUM_SETS  ),
        .NUM_SETS_L2    (NUM_SETS_L2),
        .WORD_OFF_W     (WORD_OFF_W),
        .BYTE_OFF_W     (BYTE_OFF_W),
        .START_PC       (C0_START_PC),
        .END_PC         (C0_END_PC)
    ) u_core_A (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // Write Channels
        .m_axi_awaddr   (c0_awaddr),
        .m_axi_awvalid  (c0_awvalid),
        .m_axi_awready  (c0_awready),

        .m_axi_wdata    (c0_wdata),
        .m_axi_wvalid   (c0_wvalid),
        .m_axi_wready   (c0_wready),

        .m_axi_bvalid   (c0_bvalid),
        .m_axi_bresp    (c0_bresp),
        .m_axi_bready   (c0_bready),
        
        // Read Channels
        .m_axi_araddr   (c0_araddr), 
        .m_axi_arsnoop  (c0_arsnoop),
        .m_axi_arvalid  (c0_arvalid), 
        .m_axi_arready  (c0_arready),
        .m_axi_rdata    (c0_rdata),
        .m_axi_rlast    (c0_rlast),
        .m_axi_rvalid   (c0_rvalid),
        .m_axi_rready   (c0_rready),

        // Snoop Channels
        .s_ace_acvalid  (c0_acvalid), 
        .s_ace_acaddr   (c0_acaddr), 
        .s_ace_acsnoop  (c0_acsnoop), 
        .s_ace_acready  (c0_acready),

        .s_ace_crready  (c0_crready), 
        .s_ace_crvalid  (c0_crvalid), 
        .s_ace_crresp   (c0_crresp),

        .s_ace_cdready  (c0_cdready), 
        .s_ace_cdvalid  (c0_cdvalid), 
        .s_ace_cddata   (c0_cddata), 
        .s_ace_cdlast   (c0_cdlast)
    );

    // ------------------- INSTANTIATE CORE B (ID = 1) -------------------
    single_core #( 
        .CORE_ID        (1),
        .NUM_WAYS       (NUM_WAYS  ),
        .NUM_SETS       (NUM_SETS  ),
        .NUM_SETS_L2    (NUM_SETS_L2),
        .WORD_OFF_W     (WORD_OFF_W),
        .BYTE_OFF_W     (BYTE_OFF_W),
        .START_PC       (C1_START_PC),
        .END_PC         (C1_END_PC)
    ) u_core_B (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // Write Channels
        .m_axi_awaddr   (c1_awaddr),
        .m_axi_awvalid  (c1_awvalid),
        .m_axi_awready  (c1_awready),

        .m_axi_wdata    (c1_wdata),
        .m_axi_wvalid   (c1_wvalid),
        .m_axi_wready   (c1_wready),

        .m_axi_bvalid   (c1_bvalid),
        .m_axi_bresp    (c1_bresp),
        .m_axi_bready   (c1_bready),

        // Read Channels (Connect to c1_ wires)
        .m_axi_araddr   (c1_araddr), 
        .m_axi_arsnoop  (c1_arsnoop),
        .m_axi_arvalid  (c1_arvalid), 
        .m_axi_arready  (c1_arready),
        .m_axi_rdata    (c1_rdata),
        .m_axi_rlast    (c1_rlast),
        .m_axi_rvalid   (c1_rvalid),
        .m_axi_rready   (c1_rready),

        // Snoop Channels (Connect to c1_ wires)
        .s_ace_acvalid  (c1_acvalid), 
        .s_ace_acaddr   (c1_acaddr), 
        .s_ace_acsnoop  (c1_acsnoop), 
        .s_ace_acready  (c1_acready),

        .s_ace_crready  (c1_crready), 
        .s_ace_crvalid  (c1_crvalid), 
        .s_ace_crresp   (c1_crresp),

        .s_ace_cdready  (c1_cdready), 
        .s_ace_cdvalid  (c1_cdvalid), 
        .s_ace_cddata   (c1_cddata), 
        .s_ace_cdlast   (c1_cdlast)
    );

    // ------------------- INSTANTIATE INTERCONNECT -------------------    
    ace_interconnect u_interconnect (
        .clk    (ACLK), 
        .rst_n  (ARESETn),

        // ---------------- CLIENT 0 (CORE A) ----------------
        .s0_axi_araddr  (c0_araddr), 
        .s0_axi_arsnoop (c0_arsnoop), 
        .s0_axi_arvalid (c0_arvalid), 
        .s0_axi_arready (c0_arready),

        .s0_axi_rdata   (c0_rdata),  
        .s0_axi_rvalid  (c0_rvalid),  
        .s0_axi_rlast   (c0_rlast),   
        .s0_axi_rready  (c0_rready),

        .s0_ace_acaddr  (c0_acaddr), 
        .s0_ace_acsnoop (c0_acsnoop), 
        .s0_ace_acvalid (c0_acvalid), 
        .s0_ace_acready (c0_acready),

        .s0_ace_crvalid (c0_crvalid),
        .s0_ace_crresp  (c0_crresp), 
        .s0_ace_cddata  (c0_cddata), 
        .s0_ace_cdvalid (c0_cdvalid),

        // Write channel (core0)
        .s0_axi_awaddr  (c0_awaddr),
        .s0_axi_awvalid (c0_awvalid),
        .s0_axi_awready (c0_awready),

        .s0_axi_wdata   (c0_wdata),
        .s0_axi_wvalid  (c0_wvalid),
        .s0_axi_wready  (c0_wready),

        .s0_axi_bvalid  (c0_bvalid),
        .s0_axi_bresp   (c0_bresp),
        .s0_axi_bready  (c0_bready),

        // ---------------- CLIENT 1 (CORE B) ----------------
        .s1_axi_araddr  (c1_araddr), 
        .s1_axi_arsnoop (c1_arsnoop), 
        .s1_axi_arvalid (c1_arvalid), 
        .s1_axi_arready (c1_arready),

        .s1_axi_rdata   (c1_rdata),  
        .s1_axi_rvalid  (c1_rvalid),  
        .s1_axi_rlast   (c1_rlast),   
        .s1_axi_rready  (c1_rready),

        .s1_ace_acaddr  (c1_acaddr), 
        .s1_ace_acsnoop (c1_acsnoop), 
        .s1_ace_acvalid (c1_acvalid), 
        .s1_ace_acready (c1_acready),

        .s1_ace_crvalid (c1_crvalid),
        .s1_ace_crresp  (c1_crresp), 
        .s1_ace_cddata  (c1_cddata), 
        .s1_ace_cdvalid (c1_cdvalid),

        // Write channel (core1)
        .s1_axi_awaddr  (c1_awaddr),
        .s1_axi_awvalid (c1_awvalid),
        .s1_axi_awready (c1_awready),

        .s1_axi_wdata   (c1_wdata),
        .s1_axi_wvalid  (c1_wvalid),
        .s1_axi_wready  (c1_wready),

        .s1_axi_bvalid  (c1_bvalid),
        .s1_axi_bresp   (c1_bresp),
        .s1_axi_bready  (c1_bready),

        // ---------------- MASTER PORT (connected directly to external AXI) ----------------
        .m_l3_araddr    (l3_araddr), 
        .m_l3_arvalid   (l3_arvalid), 
        .m_l3_arready   (l3_arready),

        .m_l3_rdata     (l3_rdata),   
        .m_l3_rvalid    (l3_rvalid),   
        .m_l3_rlast     (l3_rlast),     
        .m_l3_rready    (l3_rready),

        // Write/master outputs
        .m_l3_awaddr    (l3_awaddr),
        .m_l3_awvalid   (l3_awvalid),
        .m_l3_awready   (l3_awready),

        .m_l3_wdata     (l3_wdata),
        .m_l3_wvalid    (l3_wvalid),
        .m_l3_wready    (l3_wready),

        .m_l3_bvalid    (l3_bvalid),
        .m_l3_bresp     (l3_bresp),
        .m_l3_bready    (l3_bready)
    );

    // Write address channel
    assign m_axi_awid    = 2'b00;
    assign m_axi_awaddr  = l3_awaddr;
    assign m_axi_awlen   = 8'b0;         // single-beat
    assign m_axi_awsize  = 3'b110;       // 64 bytes (DATA_W = 512 bits)
    assign m_axi_awburst = 2'b01;        // INCR
    assign m_axi_awvalid = l3_awvalid;
    assign l3_awready    = m_axi_awready;

    // Write data channel
    assign m_axi_wdata   = l3_wdata;
    assign m_axi_wstrb   = {64{1'b1}};   // all bytes valid for full beat
    assign m_axi_wlast   = 1'b1;         // single-beat transfer
    assign m_axi_wvalid  = l3_wvalid;
    assign l3_wready     = m_axi_wready;

    // Write response channel
    assign l3_bvalid     = m_axi_bvalid;
    assign l3_bresp      = m_axi_bresp;
    assign m_axi_bready  = l3_bready;

    // Read address channel
    assign m_axi_arid    = 2'b00;
    assign m_axi_araddr  = l3_araddr;
    assign m_axi_arlen   = 8'b0;         // single-beat
    assign m_axi_arsize  = 3'b110;       // 64 bytes
    assign m_axi_arburst = 2'b01;        // INCR
    assign m_axi_arvalid = l3_arvalid;
    assign l3_arready    = m_axi_arready;

    // Read data channel
    assign l3_rdata      = m_axi_rdata;
    assign l3_rvalid     = m_axi_rvalid;
    assign l3_rlast      = m_axi_rlast;
    assign m_axi_rready  = l3_rready;

endmodule