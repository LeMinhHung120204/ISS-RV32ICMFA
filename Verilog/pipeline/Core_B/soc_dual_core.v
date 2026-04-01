`timescale 1ns / 1ps
//==============================================================================
// SoC Dual Core - Top-level cho hệ thống RV32 IMF Dual Core
//==============================================================================
// File: soc_dual_core.v
// Description:
//   Top-level module kết nối Core A và Core B qua ACE Interconnect.
//   Dùng để chạy Dual Core RV32 IMF theo kiến trúc Kientruc.jpg
//
// KIẾN TRÚC:
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                           SoC Dual Core                                 │
//   │  ┌─────────────────────────────┐  ┌─────────────────────────────┐      │
//   │  │         CORE A              │  │         CORE B              │      │
//   │  │   ┌───────┐                 │  │   ┌───────┐                 │      │
//   │  │   │RV32IMF│←→ I-Cache L1    │  │   │RV32IMF│←→ I-Cache L1    │      │
//   │  │   └───────┘←→ D-Cache L1    │  │   └───────┘←→ D-Cache L1    │      │
//   │  │              ↓              │  │              ↓              │      │
//   │  │         Cache L2            │  │         Cache L2            │      │
//   │  │        (CORE_ID=0)          │  │        (CORE_ID=1)          │      │
//   │  └─────────────┬───────────────┘  └─────────────┬───────────────┘      │
//   │                │         AXI ACE Bus            │                      │
//   │                └───────────────┬────────────────┘                      │
//   │                                ↓                                        │
//   │                    ┌───────────────────────┐                            │
//   │                    │    ACE Interconnect   │                            │
//   │                    │  (Cache Coherency)    │                            │
//   │                    └───────────┬───────────┘                            │
//   │                                ↓                                        │
//   │                    ┌───────────────────────┐                            │
//   │                    │      TO L3 CACHE      │                            │
//   │                    │   (Bạn của bạn làm)   │                            │
//   │                    └───────────────────────┘                            │
//   └─────────────────────────────────────────────────────────────────────────┘
//
// Cách sử dụng:
//   1. Include file này cùng với single_core.v, core_b.v, ace_interconect.v
//   2. Kết nối output L3 interface với L3 Cache của bạn
//   3. Load chương trình vào memory và chạy simulation
//==============================================================================

module soc_dual_core (
    input ACLK,                         // System Clock
    input ARESETn,                      // Active-low Reset
    
    // ===================== L3 INTERFACE (OUTPUT) =====================
    // Kết nối với L3 Cache (bạn của bạn đang làm)
    
    // Read Address (từ ACE Interconnect → L3)
    output [31:0]   m_l3_araddr,
    output          m_l3_arvalid,
    input           m_l3_arready,
    
    // Read Data (từ L3 → ACE Interconnect)
    input  [511:0]  m_l3_rdata,
    input           m_l3_rvalid,
    input           m_l3_rlast,
    output          m_l3_rready
);

    // ===================== CORE A INTERFACE =====================
    // Read Address Channel (AR)
    wire [31:0]  c0_araddr;
    wire [3:0]   c0_arsnoop;
    wire         c0_arvalid, c0_arready;
    
    // Read Data Channel (R)
    wire [511:0] c0_rdata;
    wire         c0_rvalid, c0_rlast, c0_rready;

    // Snoop Address Channel (AC) - Input to Core A
    wire [31:0]  c0_acaddr;
    wire [3:0]   c0_acsnoop;
    wire         c0_acvalid, c0_acready;

    // Snoop Response Channel (CR) - Output from Core A
    wire         c0_crvalid;
    wire [4:0]   c0_crresp;
    wire         c0_crready;

    // Snoop Data Channel (CD) - Output from Core A
    wire [511:0] c0_cddata;
    wire         c0_cdvalid;
    wire         c0_cdlast;
    wire         c0_cdready;

    // ===================== CORE B INTERFACE =====================
    // Read Address Channel (AR)
    wire [31:0]  c1_araddr;
    wire [3:0]   c1_arsnoop;
    wire         c1_arvalid, c1_arready;
    
    // Read Data Channel (R)
    wire [511:0] c1_rdata;
    wire         c1_rvalid, c1_rlast, c1_rready;

    // Snoop Address Channel (AC) - Input to Core B
    wire [31:0]  c1_acaddr;
    wire [3:0]   c1_acsnoop;
    wire         c1_acvalid, c1_acready;

    // Snoop Response Channel (CR) - Output from Core B
    wire         c1_crvalid;
    wire [4:0]   c1_crresp;
    wire         c1_crready;

    // Snoop Data Channel (CD) - Output from Core B
    wire [511:0] c1_cddata;
    wire         c1_cdvalid;
    wire         c1_cdlast;
    wire         c1_cdready;

    // Tạm thời để CR/CD ready = 1 (luôn sẵn sàng nhận)
    assign c0_crready = 1'b1;
    assign c0_cdready = 1'b1;
    assign c1_crready = 1'b1;
    assign c1_cdready = 1'b1;

    // ===================== CORE A (CORE_ID = 0) =====================
    single_core #( 
        .CORE_ID        (1'b0),             // Core A có ID = 0
        .CACHE_DATA_W   (512)
    ) u_core_A (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // AW Channel (Write Address) - Hiện chưa dùng trong ACE Interconnect
        .m_axi_awid     (), 
        .m_axi_awaddr   (), 
        .m_axi_awlen    (),
        .m_axi_awsize   (), 
        .m_axi_awburst  (), 
        .m_axi_awvalid  (),
        .m_axi_awready  (1'b1),
        .m_axi_awsnoop  (), 
        .m_axi_awdomain (),

        // W Channel (Write Data)
        .m_axi_wdata    (), 
        .m_axi_wstrb    (), 
        .m_axi_wlast    (),
        .m_axi_wvalid   (), 
        .m_axi_wready   (1'b1),

        // B Channel (Write Response)
        .m_axi_bid      (2'b0), 
        .m_axi_bresp    (2'b0), 
        .m_axi_bvalid   (1'b0), 
        .m_axi_bready   (),        

        // AR Channel (Read Address)
        .m_axi_arid     (),
        .m_axi_araddr   (c0_araddr), 
        .m_axi_arlen    (),
        .m_axi_arsize   (), 
        .m_axi_arburst  (),
        .m_axi_arvalid  (c0_arvalid), 
        .m_axi_arready  (c0_arready),
        .m_axi_arsnoop  (c0_arsnoop),
        .m_axi_ardomain (),

        // R Channel (Read Data)
        .m_axi_rid      (2'b0), 
        .m_axi_rdata    (c0_rdata),
        .m_axi_rresp    (4'b0),
        .m_axi_rlast    (c0_rlast),
        .m_axi_rvalid   (c0_rvalid),
        .m_axi_rready   (c0_rready),

        // AC Channel (Snoop Address - từ Interconnect)
        .s_ace_acvalid  (c0_acvalid),
        .s_ace_acaddr   (c0_acaddr),
        .s_ace_acsnoop  (c0_acsnoop),
        .s_ace_acready  (c0_acready),

        // CR Channel (Snoop Response - tới Interconnect)
        .s_ace_crready  (c0_crready),
        .s_ace_crvalid  (c0_crvalid), 
        .s_ace_crresp   (c0_crresp),

        // CD Channel (Snoop Data - tới Interconnect)
        .s_ace_cdready  (c0_cdready),
        .s_ace_cdvalid  (c0_cdvalid), 
        .s_ace_cddata   (c0_cddata),
        .s_ace_cdlast   (c0_cdlast)
    );

    // ===================== CORE B (CORE_ID = 1) =====================
    core_b #( 
        .CORE_ID        (1'b1),             // Core B có ID = 1
        .CACHE_DATA_W   (512)
    ) u_core_B (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // AW Channel
        .m_axi_awid     (), 
        .m_axi_awaddr   (), 
        .m_axi_awlen    (),
        .m_axi_awsize   (), 
        .m_axi_awburst  (), 
        .m_axi_awvalid  (),
        .m_axi_awready  (1'b1),
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
        .m_axi_araddr   (c1_araddr), 
        .m_axi_arlen    (),
        .m_axi_arsize   (), 
        .m_axi_arburst  (),
        .m_axi_arvalid  (c1_arvalid), 
        .m_axi_arready  (c1_arready),
        .m_axi_arsnoop  (c1_arsnoop),
        .m_axi_ardomain (),

        // R Channel
        .m_axi_rid      (2'b0), 
        .m_axi_rdata    (c1_rdata),
        .m_axi_rresp    (4'b0),
        .m_axi_rlast    (c1_rlast),
        .m_axi_rvalid   (c1_rvalid),
        .m_axi_rready   (c1_rready),

        // AC Channel
        .s_ace_acvalid  (c1_acvalid),
        .s_ace_acaddr   (c1_acaddr),
        .s_ace_acsnoop  (c1_acsnoop),
        .s_ace_acready  (c1_acready),

        // CR Channel
        .s_ace_crready  (c1_crready),
        .s_ace_crvalid  (c1_crvalid), 
        .s_ace_crresp   (c1_crresp),

        // CD Channel
        .s_ace_cdready  (c1_cdready),
        .s_ace_cdvalid  (c1_cdvalid), 
        .s_ace_cddata   (c1_cddata),
        .s_ace_cdlast   (c1_cdlast)
    );

    // ===================== ACE INTERCONNECT =====================
    // Module này đảm bảo Cache Coherency giữa 2 core
    // Khi Core A đọc data, nó snoop Core B để kiểm tra cache
    // và ngược lại
    ace_interconnect u_ace_interconnect (
        .clk        (ACLK), 
        .rst_n      (ARESETn),

        // ===== Client 0 (Core A) =====
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

        // ===== Client 1 (Core B) =====
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

        // ===== Master Port (→ L3 Cache) =====
        .m_l3_araddr    (m_l3_araddr),
        .m_l3_arvalid   (m_l3_arvalid),
        .m_l3_arready   (m_l3_arready),
        
        .m_l3_rdata     (m_l3_rdata),
        .m_l3_rvalid    (m_l3_rvalid),
        .m_l3_rlast     (m_l3_rlast),
        .m_l3_rready    (m_l3_rready)
    );

endmodule
