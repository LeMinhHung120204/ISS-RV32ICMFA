`timescale 1ns/1ps
module soc_top (
    input ACLK, ARESETn
);
    // ------------------- CORE A INTERFACE -------------------
    // Read Address (AR)
    wire [31:0]  c0_araddr;
    wire [3:0]   c0_arsnoop;
    wire         c0_arvalid, c0_arready;
    
    // Read Data (R)
    wire [511:0] c0_rdata;
    wire         c0_rvalid, c0_rlast, c0_rready;

    // Snoop Address (AC) - Input to Core
    wire [31:0]  c0_acaddr;
    wire [3:0]   c0_acsnoop;
    wire         c0_acvalid, c0_acready;

    // Snoop Response (CR) - Output from Core
    wire         c0_crvalid;
    wire [4:0]   c0_crresp;

    wire         c0_crready = 1'b1;                 // tam de vay

    // Snoop Data (CD) - Output from Core
    wire [511:0] c0_cddata;
    wire         c0_cdvalid;
    wire         c0_cdlast;
 
    wire         c0_cdready = 1'b1;                 // tam de vay

    // ------------------- L3 INTERFACE (OUTPUT OF INTERCONNECT) -------------------
    wire [31:0]  l3_araddr;
    wire         l3_arvalid;
    wire         l3_arready; // Input from L3 Cache logic

    wire [511:0] l3_rdata;
    wire         l3_rvalid;
    wire         l3_rlast;
    wire         l3_rready;

    // ================= INSTANTIATE CORE A =================
    single_core #( 
        .CORE_ID(0),
        .CACHE_DATA_W(512)
    ) u_core_A (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // AW Channel
        .m_axi_awid     (), 
        .m_axi_awaddr   (), 
        .m_axi_awlen    (),
        .m_axi_awsize   (), 
        .m_axi_awburst  (), 
        .m_axi_awvalid  (),
        .m_axi_awready  (1'b1),                     // tam thoi de vay
        .m_axi_awsnoop  (), 
        .m_axi_awdomain (),

        // W Channel
        .m_axi_wdata    (), 
        .m_axi_wstrb    (), 
        .m_axi_wlast    (),
        .m_axi_wvalid   (), 
        .m_axi_wready   (1'b1),

        // B Channel
        .m_axi_bid      (2'b0), 
        .m_axi_bresp    (2'b0), 
        .m_axi_bvalid   (1'b0), 
        .m_axi_bready   (),        

        // AR Channel
        .m_axi_arid     (),
        .m_axi_araddr   (c0_araddr), 
        .m_axi_arlen    (),
        .m_axi_arsize   (), 
        .m_axi_arburst  (),
        .m_axi_arvalid  (c0_arvalid), 
        .m_axi_arready  (c0_arready),
        .m_axi_arsnoop  (c0_arsnoop),
        .m_axi_ardomain (),

        // R Channel
        .m_axi_rid      (2'b0), 
        .m_axi_rdata    (c0_rdata),
        .m_axi_rresp    (4'b0), // Default OKAY
        .m_axi_rlast    (c0_rlast),
        .m_axi_rvalid   (c0_rvalid),
        .m_axi_rready   (c0_rready),

        // AC Channel
        .s_ace_acvalid  (c0_acvalid),
        .s_ace_acaddr   (c0_acaddr),
        .s_ace_acsnoop  (c0_acsnoop),
        .s_ace_acready  (c0_acready),

        // CR Channel
        .s_ace_crready  (c0_crready), // default = 1
        .s_ace_crvalid  (c0_crvalid), 
        .s_ace_crresp   (c0_crresp),

        // CD Channel
        .s_ace_cdready  (c0_cdready), // default = 1
        .s_ace_cdvalid  (c0_cdvalid), 
        .s_ace_cddata   (c0_cddata),
        .s_ace_cdlast   (c0_cdlast)
    );

    // ================= INSTANTIATE CORE B =================
    single_core #( 
        .CORE_ID(1),
        .CACHE_DATA_W(512)
    ) u_core_A (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // AW Channel
        .m_axi_awid     (), 
        .m_axi_awaddr   (), 
        .m_axi_awlen    (),
        .m_axi_awsize   (), 
        .m_axi_awburst  (), 
        .m_axi_awvalid  (),
        .m_axi_awready  (1'b1),                     // tam thoi de vay
        .m_axi_awsnoop  (), 
        .m_axi_awdomain (),

        // W Channel
        .m_axi_wdata    (), 
        .m_axi_wstrb    (), 
        .m_axi_wlast    (),
        .m_axi_wvalid   (), 
        .m_axi_wready   (1'b1),

        // B Channel
        .m_axi_bid      (2'b0), 
        .m_axi_bresp    (2'b0), 
        .m_axi_bvalid   (1'b0), 
        .m_axi_bready   (),        

        // AR Channel
        .m_axi_arid     (),
        .m_axi_araddr   (), 
        .m_axi_arlen    (),
        .m_axi_arsize   (), 
        .m_axi_arburst  (),
        .m_axi_arvalid  (), 
        .m_axi_arready  (),
        .m_axi_arsnoop  (),
        .m_axi_ardomain (),

        // R Channel
        .m_axi_rid      (2'b0), 
        .m_axi_rdata    (),
        .m_axi_rresp    (4'b0), // Default OKAY
        .m_axi_rlast    (),
        .m_axi_rvalid   (),
        .m_axi_rready   (),

        // AC Channel
        .s_ace_acvalid  (),
        .s_ace_acaddr   (),
        .s_ace_acsnoop  (),
        .s_ace_acready  (),

        // CR Channel
        .s_ace_crready  (), // default = 1
        .s_ace_crvalid  (), 
        .s_ace_crresp   (),

        // CD Channel
        .s_ace_cdready  (), // default = 1
        .s_ace_cdvalid  (), 
        .s_ace_cddata   (),
        .s_ace_cdlast   ()
    );

    // ================= INSTANTIATE INTERCONNECT =================
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
        // Interconnect not use cdlast và crready, cdready 

        // ---------------- CLIENT 1 (CORE B) ----------------
        .s1_axi_araddr  (32'd0), 
        .s1_axi_arsnoop (4'b0), 
        .s1_axi_arvalid (1'b0),
        .s1_axi_rready  (1'b0),
        .s1_ace_acready (1'b1),
        .s1_ace_crvalid (1'b0), 
        .s1_ace_crresp  (5'b0),
        .s1_ace_cdvalid (1'b0), 
        .s1_ace_cddata  (512'd0),

        // ---------------- MASTER PORT (TO L3 CACHE) ----------------
        .m_l3_araddr    (l3_araddr), 
        .m_l3_arvalid   (l3_arvalid), 
        .m_l3_arready   (l3_arready),
        
        .m_l3_rdata     (l3_rdata),   
        .m_l3_rvalid    (l3_rvalid),   
        .m_l3_rlast     (l3_rlast),     
        .m_l3_rready    (l3_rready)
    );
    

endmodule