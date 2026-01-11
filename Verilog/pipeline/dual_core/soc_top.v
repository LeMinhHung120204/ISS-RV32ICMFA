`timescale 1ns/1ps

module soc_top #(
    // Cau hinh cache
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter NUM_SETS_L2   = 32,
    parameter NUM_SETS_L3   = 64,
    parameter WORD_OFF_W    = 4, // 16 words
    parameter BYTE_OFF_W    = 2
)(
    input ACLK, ARESETn,

    // EXTERNAL MEMORY INTERFACE (Output from L3 Cache to Main Memory)
    output [1:0]    mem_awid,
    output [31:0]   mem_awaddr,
    output [7:0]    mem_awlen,
    output [2:0]    mem_awsize,
    output [1:0]    mem_awburst,
    output          mem_awvalid,
    input           mem_awready,

    output [511:0]  mem_wdata,
    output [63:0]   mem_wstrb,
    output          mem_wlast,
    output          mem_wvalid,
    input           mem_wready,

    input  [1:0]    mem_bid,
    input  [1:0]    mem_bresp,
    input           mem_bvalid,
    output          mem_bready,

    output [1:0]    mem_arid,
    output [31:0]   mem_araddr,
    output [7:0]    mem_arlen,
    output [2:0]    mem_arsize,
    output [1:0]    mem_arburst,
    output          mem_arvalid,
    input           mem_arready,

    input  [1:0]    mem_rid,
    input  [511:0]  mem_rdata,
    input  [1:0]    mem_rresp,
    input           mem_rlast,
    input           mem_rvalid,
    output          mem_rready
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

    // ------------------- L3 INTERFACE (Interconnect -> L3) -------------------
    wire [31:0]  l3_araddr;
    wire         l3_arvalid;
    wire         l3_arready; 
    wire [511:0] l3_rdata;
    wire         l3_rvalid;
    wire         l3_rlast;
    wire         l3_rready;


    // ------------------- INSTANTIATE CORE A (ID = 0) -------------------
    single_core #( 
        .CORE_ID        (0),
        .NUM_WAYS       (NUM_WAYS  ),
        .NUM_SETS       (NUM_SETS  ),
        .NUM_SETS_L2    (NUM_SETS_L2),
        .WORD_OFF_W     (WORD_OFF_W),
        .BYTE_OFF_W     (BYTE_OFF_W)
    ) u_core_A (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // Write Channels (Dummy/Unused for now)
        .m_axi_awready  (1'b1), 
        .m_axi_wready   (1'b1),
        
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
        .BYTE_OFF_W     (BYTE_OFF_W)
    ) u_core_B (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // Write Channels (Dummy)
        .m_axi_awready  (1'b1), 
        .m_axi_wready   (1'b1),

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

        // ---------------- MASTER PORT (TO L3 CACHE) ----------------
        // Interconnect output is AXI, but L3 input is Native. We bridge them in L3 instantiation.
        .m_l3_araddr    (l3_araddr), 
        .m_l3_arvalid   (l3_arvalid), 
        .m_l3_arready   (l3_arready),
        
        .m_l3_rdata     (l3_rdata),   
        .m_l3_rvalid    (l3_rvalid),   
        .m_l3_rlast     (l3_rlast),     
        .m_l3_rready    (l3_rready)
    );

    //  ---------------- INSTANTIATE L3 CACHE (LLC) ----------------
    L3_cache #(
        .CACHE_DATA_W   (512),
        .NUM_WAYS       (NUM_WAYS  ),
        .NUM_SETS       (NUM_SETS_L3),
        .WORD_OFF_W     (WORD_OFF_W),
        .BYTE_OFF_W     (BYTE_OFF_W)
    ) u_l3_cache (
        .ACLK       (ACLK), 
        .ARESETn    (ARESETn),

        // --- INPUT: From Interconnect (Bridge AXI -> Native) ---
        // Interconnect chi moi ho tro Read (AR channel), ta map vao Read Request của L3
        .i_req_valid    (l3_arvalid),       // Valid request
        .i_req_cmd      (2'b00),            // 00 = READ (Interconnect currently handles AR only)
        .i_req_addr     (l3_araddr),        // Address
        .o_req_ready    (l3_arready),       // Ready

        .i_wdata        (512'd0),           // Write data (Chưa nối Write channel)
        .i_wdata_valid  (1'b0),
        .o_wdata_ready  (),

        .o_rdata        (l3_rdata),         // Data tra ve
        .o_rdata_valid  (l3_rvalid),        // Valid tra ve
        .i_rdata_ready  (l3_rready),        // Interconnect san sang nhan

        // --- OUTPUT: To Main Memory (Mapped to soc_top ports) ---
        .iAWREADY   (mem_awready),
        .oAWID      (mem_awid), 
        .oAWADDR    (mem_awaddr), 
        .oAWLEN     (mem_awlen), 
        .oAWSIZE    (mem_awsize), 
        .oAWBURST   (mem_awburst), 
        .oAWVALID   (mem_awvalid),

        .iWREADY    (mem_wready),
        .oWDATA     (mem_wdata), 
        .oWSTRB     (mem_wstrb), 
        .oWLAST     (mem_wlast), 
        .oWVALID    (mem_wvalid),

        .iBID       (mem_bid), 
        .iBRESP     (mem_bresp), 
        .iBVALID    (mem_bvalid), 
        .oBREADY    (mem_bready),

        .iARREADY   (mem_arready),
        .oARID      (mem_arid), 
        .oARADDR    (mem_araddr), 
        .oARLEN     (mem_arlen), 
        .oARSIZE    (mem_arsize), 
        .oARBURST   (mem_arburst), 
        .oARVALID   (mem_arvalid),

        .iRID       (mem_rid), 
        .iRDATA     (mem_rdata), 
        .iRRESP     (mem_rresp), 
        .iRLAST     (mem_rlast), 
        .iRVALID    (mem_rvalid), 
        .oRREADY    (mem_rready)
    );

endmodule