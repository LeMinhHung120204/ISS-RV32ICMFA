`timescale 1ns/1ps

module tb_single_core;
    parameter HEX_FILE = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 
    parameter INPUT_DRAM = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/input_dram.txt";

    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    parameter CORE_ID    = 1'b0;
    parameter ID_W       = 2;
    parameter ADDR_W     = 32;
    parameter DATA_W     = 32;
    parameter RAM_ADDR_W = 5;

    reg ACLK;
    reg ARESETn;

    // --- Control Simulation ---
    // Biến này dung de gia lap phan hoi cua he thong: 
    // 0: Trả về Exclusive (Không ai có bản copy)
    // 1: Trả về Shared (Có người khác có bản copy)
    reg sim_force_shared_response; 

    // -------------------------------------------------------------------------
    // D-Cache Interfaces (AXI4 + ACE-Lite Extensions)
    // -------------------------------------------------------------------------
    wire [ID_W-1:0]     d_axi_awid, d_axi_bid, d_axi_arid, d_axi_rid;
    wire [ADDR_W-1:0]   d_axi_awaddr, d_axi_araddr;
    wire [7:0]          d_axi_awlen, d_axi_arlen;
    wire [2:0]          d_axi_awsize, d_axi_arsize;
    wire [1:0]          d_axi_awburst, d_axi_arburst;
    wire                d_axi_awvalid, d_axi_awready;
    wire [DATA_W-1:0]   d_axi_wdata, d_axi_rdata;
    wire [DATA_W/8-1:0] d_axi_wstrb;
    wire                d_axi_wlast, d_axi_wvalid, d_axi_wready;
    wire [1:0]          d_axi_bresp;
    wire [3:0]          d_axi_rresp; 
    
    wire                d_axi_bvalid, d_axi_bready;
    wire                d_axi_rlast, d_axi_rvalid, d_axi_rready;

    // -------------------------------------------------------------------------
    // I-Cache Interfaces (AXI4 Read Only)
    // -------------------------------------------------------------------------
    wire [ID_W-1:0]     i_axi_arid, i_axi_rid;
    wire [ADDR_W-1:0]   i_axi_araddr;
    wire [7:0]          i_axi_arlen;
    wire [2:0]          i_axi_arsize;
    wire [1:0]          i_axi_arburst;
    wire                i_axi_arvalid, i_axi_arready;
    wire [DATA_W-1:0]   i_axi_rdata;
    wire [1:0]          i_axi_rresp;
    wire                i_axi_rlast, i_axi_rvalid, i_axi_rready;

    // -------------------------------------------------------------------------
    // ACE Signals (Snoop Channels)
    // -------------------------------------------------------------------------
    // Output from Core (Asking snoop)
    wire [3:0]          m_d_ace_arsnoop; 
    wire [2:0]          m_d_ace_awsnoop; // it dùng cho WriteBack/Evict
    wire [1:0]          m_d_ace_awdomain, m_d_ace_awbar;
    wire [1:0]          m_d_ace_ardomain, m_d_ace_arbar;

    // Input to Core (Snoop requests from system - Single Core thi khong ai hoi no)
    wire                m_ace_acvalid = 1'b0; 
    wire [ADDR_W-1:0]   m_ace_acaddr  = {ADDR_W{1'b0}};
    wire [3:0]          m_ace_acsnoop = 4'b0;
    wire                m_ace_acready; // Core ready to accept snoop

    // Responses from Core (If it was snooped)
    wire                m_ace_crvalid, m_ace_cdvalid, m_ace_cdlast;
    wire [4:0]          m_ace_crresp;
    wire [DATA_W-1:0]   m_ace_cddata;
    
    // Testbench tie-offs (Fake Interconnect)
    wire m_ace_crready = 1'b1; // Always ready to receive snoop response
    wire m_ace_cdready = 1'b1; // Always ready to receive snoop data

    // -------------------------------------------------------------------------
    // 2. Instantiate Instances
    // -------------------------------------------------------------------------
    core_tile #(
        .CORE_ID(CORE_ID), 
        .ID_W   (ID_W), 
        .ADDR_W (ADDR_W), 
        .DATA_W (DATA_W)
    ) u_core (
        .ACLK(ACLK), 
        .ARESETn(ARESETn),

        // --- D-Cache AXI ---
        .m_d_axi_awready    (d_axi_awready), 
        .m_d_axi_awid       (d_axi_awid), 
        .m_d_axi_awaddr     (d_axi_awaddr), 
        .m_d_axi_awlen      (d_axi_awlen), 
        .m_d_axi_awsize     (d_axi_awsize), 
        .m_d_axi_awburst    (d_axi_awburst), 
        .m_d_axi_awvalid    (d_axi_awvalid),
        .m_d_axi_wready     (d_axi_wready), 
        .m_d_axi_wdata      (d_axi_wdata), 
        .m_d_axi_wstrb      (d_axi_wstrb), 
        .m_d_axi_wlast      (d_axi_wlast), 
        .m_d_axi_wvalid     (d_axi_wvalid),
        .m_d_axi_bid        (d_axi_bid), 
        .m_d_axi_bresp      (d_axi_bresp), 
        .m_d_axi_bvalid     (d_axi_bvalid), 
        .m_d_axi_bready     (d_axi_bready),
        .m_d_axi_arready    (d_axi_arready), 
        .m_d_axi_arid       (d_axi_arid), 
        .m_d_axi_araddr     (d_axi_araddr), 
        .m_d_axi_arlen      (d_axi_arlen), 
        .m_d_axi_arsize     (d_axi_arsize), 
        .m_d_axi_arburst    (d_axi_arburst), 
        .m_d_axi_arvalid    (d_axi_arvalid),
        .m_d_axi_rid        (d_axi_rid), 
        .m_d_axi_rdata      (d_axi_rdata), 
        
        // [QUAN TRỌNG] Nối RRESP 4 bit
        .m_d_axi_rresp      (d_axi_rresp), 
        
        .m_d_axi_rlast      (d_axi_rlast), 
        .m_d_axi_rvalid     (d_axi_rvalid), 
        .m_d_axi_rready     (d_axi_rready),
        
        // --- ACE Tie-offs & Signals ---
        .m_ace_acvalid  (m_ace_acvalid), 
        .m_ace_acaddr   (m_ace_acaddr), 
        .m_ace_acsnoop  (m_ace_acsnoop), 
        .m_ace_acready  (m_ace_acready),
        
        .m_ace_crready  (m_ace_crready), 
        .m_ace_crvalid  (m_ace_crvalid), 
        .m_ace_crresp   (m_ace_crresp),
        
        .m_ace_cdready  (m_ace_cdready), 
        .m_ace_cdvalid  (m_ace_cdvalid), 
        .m_ace_cddata   (m_ace_cddata), 
        .m_ace_cdlast   (m_ace_cdlast),

        // ACE Outputs (Core asking questions)
        .m_d_ace_awsnoop    (m_d_ace_awsnoop), 
        .m_d_ace_awdomain   (m_d_ace_awdomain), 
        .m_d_ace_awbar      (m_d_ace_awbar),
        .m_d_ace_arsnoop    (m_d_ace_arsnoop),
        .m_d_ace_ardomain   (m_d_ace_ardomain), 
        .m_d_ace_arbar      (m_d_ace_arbar),

        // --- I-Cache AXI ---
        .m_i_axi_arready    (i_axi_arready), 
        .m_i_axi_arid       (i_axi_arid), 
        .m_i_axi_araddr     (i_axi_araddr), 
        .m_i_axi_arlen      (i_axi_arlen), 
        .m_i_axi_arsize     (i_axi_arsize), 
        .m_i_axi_arburst    (i_axi_arburst), 
        .m_i_axi_arvalid    (i_axi_arvalid),
        .m_i_axi_rid        (i_axi_rid), 
        .m_i_axi_rdata      (i_axi_rdata), 
        .m_i_axi_rresp      (i_axi_rresp), 
        .m_i_axi_rlast      (i_axi_rlast), 
        .m_i_axi_rvalid     (i_axi_rvalid), 
        .m_i_axi_rready     (i_axi_rready)
    );

    // -------------------------------------------------------------------------
    // 3. Memory Models & Interconnect Logic
    // -------------------------------------------------------------------------

    // INSTRUCTION RAM
    DataMem_wrapper #(
        .WIDTH_ADDR (RAM_ADDR_W), 
        .ID_W       (ID_W), 
        .DATA_W     (DATA_W)
    ) u_i_mem (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        .i_axi_arvalid  (i_axi_arvalid), 
        .o_axi_arready  (i_axi_arready), 
        .i_axi_arid     (i_axi_arid), 
        .i_axi_araddr   (i_axi_araddr),
        .i_axi_arlen    (i_axi_arlen), 
        .i_axi_arsize   (i_axi_arsize), 
        .i_axi_arburst  (i_axi_arburst),
        .o_axi_rvalid   (i_axi_rvalid), 
        .i_axi_rready   (i_axi_rready), 
        .o_axi_rid      (i_axi_rid), 
        .o_axi_rdata    (i_axi_rdata),
        .o_axi_rresp    (i_axi_rresp),
        .o_axi_rlast    (i_axi_rlast),
        
        // Tie off writes
        .i_axi_awvalid  (1'b0), 
        .i_axi_wvalid   (1'b0), 
        .i_axi_bready   (1'b1),
        .i_axi_awaddr   ({DATA_W{1'b0}}), 
        .i_axi_awid     ({ID_W{1'b0}}), 
        .i_axi_awlen    (8'b0), 
        .i_axi_awsize   (3'b0), 
        .i_axi_awburst  (2'b0),
        .i_axi_wdata    ({DATA_W{1'b0}}), 
        .i_axi_wstrb    ({(DATA_W/8){1'b0}}), 
        .i_axi_wlast    (1'b0)
    );

    // -------------------------------------------------------------------------
    // DATA RAM (Fake Interconnect Logic for ACE)
    // -------------------------------------------------------------------------
    wire [1:0] mem_rresp_lower; // Phan hoi goc tu Memory (OKAY, EXOKAY...)

    DataMem_wrapper #(
        .WIDTH_ADDR (RAM_ADDR_W), 
        .ID_W       (ID_W), 
        .DATA_W     (DATA_W)
    ) u_d_mem (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        .i_axi_awvalid  (d_axi_awvalid), 
        .o_axi_awready  (d_axi_awready), 
        .i_axi_awaddr   (d_axi_awaddr),
        .i_axi_awlen    (d_axi_awlen), 
        .i_axi_awsize   (d_axi_awsize), 
        .i_axi_awburst  (d_axi_awburst),
        .i_axi_wvalid   (d_axi_wvalid), 
        .o_axi_wready   (d_axi_wready), 
        .i_axi_wdata    (d_axi_wdata), 
        .i_axi_wstrb    (d_axi_wstrb), 
        .i_axi_wlast    (d_axi_wlast),
        .o_axi_bvalid   (d_axi_bvalid), 
        .i_axi_bready   (d_axi_bready), 
        .o_axi_bid      (d_axi_bid), 
        .o_axi_bresp    (d_axi_bresp),
        .i_axi_arvalid  (d_axi_arvalid), 
        .o_axi_arready  (d_axi_arready), 
        .i_axi_arid     (d_axi_arid), 
        .i_axi_araddr   (d_axi_araddr),
        .i_axi_arlen    (d_axi_arlen), 
        .i_axi_arsize   (d_axi_arsize), 
        .i_axi_arburst  (d_axi_arburst),
        .o_axi_rvalid   (d_axi_rvalid), 
        .i_axi_rready   (d_axi_rready), 
        .o_axi_rid      (d_axi_rid), 
        .o_axi_rdata    (d_axi_rdata),
        
        .o_axi_rresp    (mem_rresp_lower), // Chi lay 2 bit chuan tu Memory
        
        .o_axi_rlast    (d_axi_rlast)
    );

    // -------------------------------------------------------------------------
    // [LOGIC GIA LAP SNOOP RESPONSE]
    // -------------------------------------------------------------------------
    // Ghep 2 bit ACE (IsShared, PassDirty) vao 2 bit AXI chuan
    // RRESP[3] = PassDirty (O day gia su luon = 0)
    // RRESP[2] = IsShared (Dieu khien boi sim_force_shared_response)
    // RRESP[1:0] = OKAY (00) tu Memory
    assign d_axi_rresp = {1'b0, sim_force_shared_response, mem_rresp_lower};

    // -------------------------------------------------------------------------
    // 4. Simulation Process
    // -------------------------------------------------------------------------
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    initial begin
        // 1. Reset
        ARESETn = 0;
        sim_force_shared_response = 0; // default Exclusive (E)
        #100;
        ARESETn = 1;
        #20;

        // 2. Load Memory
        $display("--------------------------------------------------");
        $display("Loading Hex File...");
        $readmemh(HEX_FILE, u_i_mem.u_DataMem.mem);
        $readmemh(INPUT_DRAM, u_d_mem.u_DataMem.mem);
        $display("--------------------------------------------------");

        // 3. Scenario 1: Refill voi trang thai Exclusive (E)
        // Cache se hoat dong binh thuong, line moi se o state E
        $display("[SCENARIO 1] Running with RRESP[2]=0 (Not Shared / Exclusive)");
        sim_force_shared_response = 1'b0; 
        #2000; 

        // // 4. Scenario 2: Refill voi trang thai Shared (S)
        // // Gia lap tinh huong co Core khac cung dang giu data nay
        // // Cache line moi se o state S.
        // $display("[SCENARIO 2] Switching to RRESP[2]=1 (Is Shared)");
        // sim_force_shared_response = 1'b1;
        // #2000;

        // // 5. Quay lai Exclusive
        // $display("[SCENARIO 3] Switching back to Exclusive");
        // sim_force_shared_response = 1'b0;
        #2000;

        $display("Simulation Finished.");
        $finish;
    end
    
    // -------------------------------------------------------------------------
    // 5. Advanced Monitor (Hien thi thong tin ACE)
    // -------------------------------------------------------------------------
    always @(posedge ACLK) begin
        // Monitor khi Core gui AR Request (Refill)
        if (d_axi_arvalid && d_axi_arready) begin
            $display("[AXI-AR] Time=%t | Addr=0x%h | ARSNOOP=%b (%s)", 
                     $time, d_axi_araddr, m_d_ace_arsnoop,
                     (m_d_ace_arsnoop == 4'b0000) ? "ReadNoSnoop" :
                     (m_d_ace_arsnoop == 4'b0001) ? "ReadShared" :
                     (m_d_ace_arsnoop == 4'b0010) ? "ReadClean" :
                     (m_d_ace_arsnoop == 4'b0011) ? "ReadNotSharedDirty" : "Other");
        end

        // Monitor khi Core nhan Data Response (Kem thong tin Snoop)
        if (d_axi_rvalid && d_axi_rready && d_axi_rlast) begin
            $display("[AXI-R ] Time=%t | Data=0x%h | RRESP=%b (IsShared=%b)", 
                     $time, d_axi_rdata, d_axi_rresp, d_axi_rresp[2]);
        end
    end

endmodule