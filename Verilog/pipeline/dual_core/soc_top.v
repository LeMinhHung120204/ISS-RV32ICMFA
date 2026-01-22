`timescale 1ns/1ps

module soc_top #(
    // Cau hinh core
    parameter C0_START_PC   = 32'd0,
    parameter C0_END_PC     = 32'h00000100,

    parameter C1_START_PC   = 32'h00000100,
    parameter C1_END_PC     = 32'h00000200,

    // Cau hinh cache
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter NUM_SETS_L2   = 32,
    parameter WORD_OFF_W    = 4, // 16 words
    parameter BYTE_OFF_W    = 2,
    parameter DATA_W        = 32,
    parameter STRB_W        = DATA_W/8
)(
    input ACLK, ARESETn,
    input c0_stall, c1_stall, // for debug purpose only

    // EXTERNAL MEMORY AXI4 MASTER INTERFACE (to external memory)
    output [1:0]    m_axi_awid,
    output [31:0]   m_axi_awaddr,
    output [7:0]    m_axi_awlen,
    output [2:0]    m_axi_awsize,
    output [1:0]    m_axi_awburst,
    output          m_axi_awvalid,
    input           m_axi_awready,

    output [DATA_W-1:0]  m_axi_wdata,
    output [STRB_W-1:0]  m_axi_wstrb,
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
    input  [DATA_W-1:0] m_axi_rdata,
    input  [1:0]    m_axi_rresp,
    input           m_axi_rlast,
    input           m_axi_rvalid,
    output          m_axi_rready
);

    // INTERNAL WIRES
    // ------------------- CORE A INTERFACE -------------------
    wire [1:0]   c0_arid;   // Added
    wire [31:0]  c0_araddr;
    wire [3:0]   c0_arsnoop;
    wire         c0_arvalid, c0_arready;
    wire [1:0]   c0_rid;    // Added
    wire [DATA_W-1:0] c0_rdata;
    wire [1:0]   c0_rresp;  // Added
    wire         c0_rvalid, c0_rlast, c0_rready;
    wire [31:0]  c0_acaddr;
    wire [3:0]   c0_acsnoop;
    wire         c0_acvalid, c0_acready;
    wire         c0_crvalid;
    wire [4:0]   c0_crresp;
    wire         c0_crready = 1'b1; 
    wire [DATA_W-1:0] c0_cddata;
    wire         c0_cdvalid, c0_cdlast;
    wire         c0_cdready = 1'b1; 

    // Write channel wires for core0
    wire [1:0]   c0_awid;   // Added
    wire [31:0]  c0_awaddr;
    wire [7:0]   c0_awlen, c0_arlen;
    wire [2:0]   c0_awsize, c0_arsize;
    wire [1:0]   c0_awburst, c0_arburst;
    wire         c0_awvalid, c0_awready;
    wire [DATA_W-1:0] c0_wdata;
    wire [STRB_W-1:0] c0_wstrb;
    wire         c0_wlast;
    wire         c0_wvalid, c0_wready;
    wire [1:0]   c0_bid;    // Added
    wire         c0_bvalid;
    wire [1:0]   c0_bresp;
    wire         c0_bready;

    // ------------------- CORE B INTERFACE -------------------
    wire [1:0]   c1_arid;   // Added
    wire [31:0]  c1_araddr;
    wire [3:0]   c1_arsnoop;
    wire         c1_arvalid, c1_arready;
    wire [1:0]   c1_rid;    // Added
    wire [DATA_W-1:0] c1_rdata;
    wire [1:0]   c1_rresp;  // Added
    wire         c1_rvalid, c1_rlast, c1_rready;
    wire [31:0]  c1_acaddr;
    wire [3:0]   c1_acsnoop;
    wire         c1_acvalid, c1_acready;
    wire         c1_crvalid;
    wire [4:0]   c1_crresp;
    wire         c1_crready = 1'b1;
    wire [DATA_W-1:0] c1_cddata;
    wire         c1_cdvalid, c1_cdlast;
    wire         c1_cdready = 1'b1; 

    // Write channel wires for core1
    wire [1:0]   c1_awid;   // Added
    wire [31:0]  c1_awaddr;
    wire [7:0]   c1_awlen, c1_arlen;
    wire [2:0]   c1_awsize, c1_arsize;
    wire [1:0]   c1_awburst, c1_arburst;
    wire         c1_awvalid, c1_awready;
    wire [DATA_W-1:0] c1_wdata;
    wire [STRB_W-1:0] c1_wstrb;
    wire         c1_wlast;
    wire         c1_wvalid, c1_wready;
    wire [1:0]   c1_bid;    // Added
    wire         c1_bvalid;
    wire [1:0]   c1_bresp;
    wire         c1_bready;

    // --- Memory bridge wires (connect interconnect <-> top-level external AXI fields)
    // These provide the small native memory interface that `ace_interconnect` drives;
    // `soc_top` then expands them into full AXI4 fields (ID/LEN/SIZE/BURST, etc.).
    wire [1:0]   mem_arid;  // Added
    wire [31:0]  mem_araddr;
    wire [7:0]   mem_arlen, mem_awlen;
    wire [2:0]   mem_arsize, mem_awsize;
    wire [1:0]   mem_arburst, mem_awburst;
    wire         mem_arvalid, mem_arready;
    wire [1:0]   mem_rid;   // Added
    wire [DATA_W-1:0] mem_rdata;
    wire [1:0]   mem_rresp; // Added
    wire         mem_rvalid, mem_rlast, mem_rready;

    wire [1:0]   mem_awid;  // Added
    wire [31:0]  mem_awaddr;
    wire         mem_awvalid, mem_awready;
    wire [DATA_W-1:0] mem_wdata;
    wire [STRB_W-1:0] mem_wstrb;
    wire         mem_wlast;
    wire         mem_wvalid, mem_wready;
    wire [1:0]   mem_bid;   // Added
    wire         mem_bvalid;
    wire [1:0]   mem_bresp;
    wire         mem_bready;

    // compute AXI size field from DATA_W/STRB_W
    localparam [2:0] AW_SIZE = $clog2(STRB_W);


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
        .test_stall     (c0_stall), // for debug purpose only
        
        // Write Channels
        .m_axi_awid     (c0_awid),
        .m_axi_awaddr   (c0_awaddr),
        .m_axi_awlen    (c0_awlen),
        .m_axi_awsize   (c0_awsize),
        .m_axi_awburst  (c0_awburst),
        .m_axi_awvalid  (c0_awvalid),
        .m_axi_awready  (c0_awready),

        .m_axi_wdata    (c0_wdata),
        .m_axi_wstrb    (c0_wstrb),
        .m_axi_wlast    (c0_wlast),
        .m_axi_wvalid   (c0_wvalid),
        .m_axi_wready   (c0_wready),

        .m_axi_bid      (c0_bid),
        .m_axi_bvalid   (c0_bvalid),
        .m_axi_bresp    (c0_bresp),
        .m_axi_bready   (c0_bready),
        
        // Read Channels
        .m_axi_arid     (c0_arid),
        .m_axi_araddr   (c0_araddr), 
        .m_axi_arlen    (c0_arlen),
        .m_axi_arsize   (c0_arsize),
        .m_axi_arburst  (c0_arburst),
        .m_axi_arsnoop  (c0_arsnoop),
        .m_axi_arvalid  (c0_arvalid), 
        .m_axi_arready  (c0_arready),
        .m_axi_rid      (c0_rid),
        .m_axi_rdata    (c0_rdata),
        .m_axi_rresp    (c0_rresp),
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
        .test_stall     (c1_stall), // for debug purpose only
        
        // Write Channels
        .m_axi_awid     (c1_awid),
        .m_axi_awaddr   (c1_awaddr),
        .m_axi_awlen    (c1_awlen),
        .m_axi_awsize   (c1_awsize),
        .m_axi_awburst  (c1_awburst),
        .m_axi_awvalid  (c1_awvalid),
        .m_axi_awready  (c1_awready),

        .m_axi_wdata    (c1_wdata),
        .m_axi_wstrb    (c1_wstrb),
        .m_axi_wlast    (c1_wlast),
        .m_axi_wvalid   (c1_wvalid),
        .m_axi_wready   (c1_wready),

        .m_axi_bid      (c1_bid),
        .m_axi_bvalid   (c1_bvalid),
        .m_axi_bresp    (c1_bresp),
        .m_axi_bready   (c1_bready),

        // Read Channels (Connect to c1_ wires)
        .m_axi_arid     (c1_arid),
        .m_axi_araddr   (c1_araddr), 
        .m_axi_arlen    (c1_arlen),
        .m_axi_arsize   (c1_arsize),
        .m_axi_arburst  (c1_arburst),
        .m_axi_arsnoop  (c1_arsnoop),
        .m_axi_arvalid  (c1_arvalid), 
        .m_axi_arready  (c1_arready),
        .m_axi_rid      (c1_rid),
        .m_axi_rdata    (c1_rdata),
        .m_axi_rresp    (c1_rresp),
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
        .s0_axi_arid    (c0_arid),
        .s0_axi_araddr  (c0_araddr), 
        .s0_axi_arlen   (c0_arlen),
        .s0_axi_arsize  (c0_arsize),
        .s0_axi_arburst (c0_arburst),
        .s0_axi_arsnoop (c0_arsnoop), 
        .s0_axi_arvalid (c0_arvalid), 
        .s0_axi_arready (c0_arready),

        .s0_axi_rid     (c0_rid),
        .s0_axi_rdata   (c0_rdata),  
        .s0_axi_rresp   (c0_rresp),
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
        .s0_axi_awid    (c0_awid),
        .s0_axi_awaddr  (c0_awaddr),
        .s0_axi_awlen   (c0_awlen),
        .s0_axi_awsize  (c0_awsize),
        .s0_axi_awburst (c0_awburst),
        .s0_axi_awvalid (c0_awvalid),
        .s0_axi_awready (c0_awready),

        .s0_axi_wdata   (c0_wdata),
        .s0_axi_wstrb   (c0_wstrb),
        .s0_axi_wlast   (c0_wlast),
        .s0_axi_wvalid  (c0_wvalid),
        .s0_axi_wready  (c0_wready),

        .s0_axi_bid     (c0_bid),
        .s0_axi_bvalid  (c0_bvalid),
        .s0_axi_bresp   (c0_bresp),
        .s0_axi_bready  (c0_bready),

        // ---------------- CLIENT 1 (CORE B) ----------------
        .s1_axi_arid    (c1_arid),
        .s1_axi_araddr  (c1_araddr), 
        .s1_axi_arlen   (c1_arlen),
        .s1_axi_arsize  (c1_arsize),
        .s1_axi_arburst (c1_arburst),
        .s1_axi_arsnoop (c1_arsnoop), 
        .s1_axi_arvalid (c1_arvalid), 
        .s1_axi_arready (c1_arready),

        .s1_axi_rid     (c1_rid),
        .s1_axi_rdata   (c1_rdata),  
        .s1_axi_rresp   (c1_rresp),
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
        .s1_axi_awid    (c1_awid),
        .s1_axi_awaddr  (c1_awaddr),
        .s1_axi_awlen   (c1_awlen),
        .s1_axi_awsize  (c1_awsize),
        .s1_axi_awburst (c1_awburst),
        .s1_axi_awvalid (c1_awvalid),
        .s1_axi_awready (c1_awready),

        .s1_axi_wdata   (c1_wdata),
        .s1_axi_wstrb   (c1_wstrb),
        .s1_axi_wlast   (c1_wlast),
        .s1_axi_wvalid  (c1_wvalid),
        .s1_axi_wready  (c1_wready),

        .s1_axi_bid     (c1_bid),
        .s1_axi_bvalid  (c1_bvalid),
        .s1_axi_bresp   (c1_bresp),
        .s1_axi_bready  (c1_bready),

        // ---------------- MASTER PORT (connected directly to external AXI) ----------------
        .mem_arid       (mem_arid),
        .mem_araddr     (mem_araddr), 
        .mem_arlen      (mem_arlen),
        .mem_arsize     (mem_arsize),
        .mem_arburst    (mem_arburst),
        .mem_arvalid    (mem_arvalid), 
        .mem_arready    (mem_arready),

        .mem_rid        (mem_rid),
        .mem_rdata      (mem_rdata),   
        .mem_rresp      (mem_rresp),
        .mem_rvalid     (mem_rvalid),   
        .mem_rlast      (mem_rlast),     
        .mem_rready     (mem_rready),

        // Write/master outputs
        .mem_awid       (mem_awid),
        .mem_awaddr     (mem_awaddr),
        .mem_awlen      (mem_awlen),
        .mem_awsize     (mem_awsize),
        .mem_awburst    (mem_awburst),
        .mem_awvalid    (mem_awvalid),
        .mem_awready    (mem_awready),

        .mem_wdata      (mem_wdata),
        .mem_wstrb      (mem_wstrb),
        .mem_wlast      (mem_wlast),
        .mem_wvalid     (mem_wvalid),
        .mem_wready     (mem_wready),

        .mem_bid        (mem_bid),
        .mem_bvalid     (mem_bvalid),
        .mem_bresp      (mem_bresp),
        .mem_bready     (mem_bready)
    );

    // Write address channel
    assign m_axi_awid    = mem_awid;
    assign m_axi_awaddr  = mem_awaddr;
    assign m_axi_awlen   = mem_awlen;
    assign m_axi_awsize  = mem_awsize;
    assign m_axi_awburst = mem_awburst;
    assign m_axi_awvalid = mem_awvalid;
    assign mem_awready   = m_axi_awready;

    // Write data channel
    assign m_axi_wdata   = mem_wdata;
    assign m_axi_wstrb   = mem_wstrb;
    assign m_axi_wlast   = mem_wlast;
    assign m_axi_wvalid  = mem_wvalid;
    assign mem_wready    = m_axi_wready;

    // Write response channel
    assign mem_bid       = m_axi_bid;
    assign mem_bvalid    = m_axi_bvalid;
    assign mem_bresp     = m_axi_bresp;
    assign m_axi_bready  = mem_bready;

    // Read address channel
    assign m_axi_arid    = mem_arid;
    assign m_axi_araddr  = mem_araddr;
    assign m_axi_arlen   = mem_arlen;
    assign m_axi_arsize  = mem_arsize;
    assign m_axi_arburst = mem_arburst;
    assign m_axi_arvalid = mem_arvalid;
    assign mem_arready   = m_axi_arready;

    // Read data channel
    assign mem_rid       = m_axi_rid;
    assign mem_rdata     = m_axi_rdata;
    assign mem_rresp     = m_axi_rresp;
    assign mem_rvalid    = m_axi_rvalid;
    assign mem_rlast     = m_axi_rlast;
    assign m_axi_rready  = mem_rready;

endmodule