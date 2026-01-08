`timescale 1ns/1ps

module tb_single_core;
    parameter HEX_FILE = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 
    
    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    parameter CORE_ID    = 1'b0;
    parameter ID_W       = 2;
    parameter ADDR_W     = 32;
    parameter DATA_W     = 32;
    parameter STRB_W     = DATA_W/8;
    parameter RAM_ADDR_W = 5;

    reg ACLK;
    reg ARESETn;

    // --- Control Simulation ---
    // 0: Exclusive (E), 1: Shared (S)
    reg sim_force_shared_response; 

    // -------------------------------------------------------------------------
    // Unified AXI4 Interface (L2 <-> Memory)
    // -------------------------------------------------------------------------
    wire [ID_W-1:0]     axi_awid, axi_bid, axi_arid, axi_rid;
    wire [ADDR_W-1:0]   axi_awaddr, axi_araddr;
    wire [7:0]          axi_awlen, axi_arlen;
    wire [2:0]          axi_awsize, axi_arsize;
    wire [1:0]          axi_awburst, axi_arburst;
    wire                axi_awvalid, axi_awready;
    wire [DATA_W-1:0]   axi_wdata, axi_rdata;
    wire [STRB_W-1:0]   axi_wstrb;
    wire                axi_wlast, axi_wvalid, axi_wready;
    wire [1:0]          axi_bresp;
    wire [3:0]          axi_rresp; // 4-bit (2 bit AXI + 2 bit ACE)
    
    wire                axi_bvalid, axi_bready;
    wire                axi_rlast, axi_rvalid, axi_rready;

    // ACE Signals (Output from Core - ignored by simple RAM)
    wire [2:0]          axi_awsnoop;
    wire [3:0]          axi_arsnoop;
    wire [1:0]          axi_awdomain, axi_ardomain;

    // -------------------------------------------------------------------------
    // Snoop Channels (Input to Core - Single Core Testbench -> Tie low)
    // -------------------------------------------------------------------------
    // Vì đây là Single Core TB, không có ai snoop nó cả.
    reg                 s_ace_acvalid = 0;
    reg  [ADDR_W-1:0]   s_ace_acaddr  = 0;
    reg  [3:0]          s_ace_acsnoop = 0;
    wire                s_ace_acready;

    wire                s_ace_crvalid, s_ace_cdvalid; // Outputs monitor
    wire [4:0]          s_ace_crresp;
    wire [DATA_W-1:0]   s_ace_cddata;

    // -------------------------------------------------------------------------
    // 2. Instantiate DUT (Single Core)
    // -------------------------------------------------------------------------
    single_core #(
        .CORE_ID(CORE_ID), 
        .ID_W   (ID_W), 
        .ADDR_W (ADDR_W), 
        .DATA_W (DATA_W)
    ) u_core (
        .ACLK(ACLK), 
        .ARESETn(ARESETn),

        // --- AXI4 ACE Master Interface ---
        // Write Address
        .m_axi_awid     (axi_awid),
        .m_axi_awaddr   (axi_awaddr),
        .m_axi_awlen    (axi_awlen),
        .m_axi_awsize   (axi_awsize),
        .m_axi_awburst  (axi_awburst),
        .m_axi_awvalid  (axi_awvalid),
        .m_axi_awready  (axi_awready),
        .m_axi_awsnoop  (axi_awsnoop),
        .m_axi_awdomain (axi_awdomain),

        // Write Data
        .m_axi_wdata    (axi_wdata),
        .m_axi_wstrb    (axi_wstrb),
        .m_axi_wlast    (axi_wlast),
        .m_axi_wvalid   (axi_wvalid),
        .m_axi_wready   (axi_wready),

        // Write Response
        .m_axi_bid      (axi_bid),
        .m_axi_bresp    (axi_bresp),
        .m_axi_bvalid   (axi_bvalid),
        .m_axi_bready   (axi_bready),

        // Read Address
        .m_axi_arid     (axi_arid),
        .m_axi_araddr   (axi_araddr),
        .m_axi_arlen    (axi_arlen),
        .m_axi_arsize   (axi_arsize),
        .m_axi_arburst  (axi_arburst),
        .m_axi_arvalid  (axi_arvalid),
        .m_axi_arready  (axi_arready),
        .m_axi_arsnoop  (axi_arsnoop),
        .m_axi_ardomain (axi_ardomain),

        // Read Data
        .m_axi_rid      (axi_rid),
        .m_axi_rdata    (axi_rdata),
        .m_axi_rresp    (axi_rresp), // 4 bit RRESP
        .m_axi_rlast    (axi_rlast),
        .m_axi_rvalid   (axi_rvalid),
        .m_axi_rready   (axi_rready),

        // --- Snoop Interface (Tie Off for Single Core TB) ---
        .s_ace_acvalid  (s_ace_acvalid),
        .s_ace_acaddr   (s_ace_acaddr),
        .s_ace_acsnoop  (s_ace_acsnoop),
        .s_ace_acready  (s_ace_acready),

        // Response channels (Outputs)
        .s_ace_crready  (1'b1), // Always ready to sink
        .s_ace_crvalid  (s_ace_crvalid),
        .s_ace_crresp   (s_ace_crresp),
        
        .s_ace_cdready  (1'b1), // Always ready to sink
        .s_ace_cdvalid  (s_ace_cdvalid),
        .s_ace_cddata   (s_ace_cddata),
        .s_ace_cdlast   ()
    );

    // -------------------------------------------------------------------------
    // 3. Unified Memory Model (Fake Interconnect + RAM)
    // -------------------------------------------------------------------------
    // Vì L2 Unified nên ta chỉ cần 1 cục RAM chung cho cả I và D
    
    wire [1:0] mem_rresp_lower; // 2 bit chuẩn từ RAM (OKAY...)

    DataMem_wrapper #(
        .WIDTH_ADDR (RAM_ADDR_W), 
        .ID_W       (ID_W), 
        .DATA_W     (DATA_W)
    ) u_unified_mem (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
        // Write Path
        .i_axi_awid     (axi_awid), 
        .i_axi_awvalid  (axi_awvalid), 
        .o_axi_awready  (axi_awready), 
        .i_axi_awaddr   (axi_awaddr),
        .i_axi_awlen    (axi_awlen), 
        .i_axi_awsize   (axi_awsize), 
        .i_axi_awburst  (axi_awburst),
        
        .i_axi_wvalid   (axi_wvalid), 
        .o_axi_wready   (axi_wready), 
        .i_axi_wdata    (axi_wdata), 
        .i_axi_wstrb    (axi_wstrb), 
        .i_axi_wlast    (axi_wlast),
        
        .o_axi_bvalid   (axi_bvalid), 
        .i_axi_bready   (axi_bready), 
        .o_axi_bid      (axi_bid), 
        .o_axi_bresp    (axi_bresp),

        // Read Path
        .i_axi_arvalid  (axi_arvalid), 
        .o_axi_arready  (axi_arready), 
        .i_axi_arid     (axi_arid), 
        .i_axi_araddr   (axi_araddr),
        .i_axi_arlen    (axi_arlen), 
        .i_axi_arsize   (axi_arsize), 
        .i_axi_arburst  (axi_arburst),
        
        .o_axi_rvalid   (axi_rvalid), 
        .i_axi_rready   (axi_rready), 
        .o_axi_rid      (axi_rid), 
        .o_axi_rdata    (axi_rdata),
        .o_axi_rresp    (mem_rresp_lower), // RAM trả về 2 bit chuẩn
        .o_axi_rlast    (axi_rlast)
    );

    // -------------------------------------------------------------------------
    // [LOGIC GIẢ LẬP SNOOP RESPONSE]
    // -------------------------------------------------------------------------
    // Ghép 2 bit ACE (PassDirty, IsShared) vào 2 bit AXI chuẩn
    // RRESP[3] = PassDirty (Ở đây giả sử luôn = 0 vì Memory không Dirty)
    // RRESP[2] = IsShared (Điều khiển bởi sim_force_shared_response)
    // RRESP[1:0] = OKAY (00) từ Memory
    assign axi_rresp = {1'b0, sim_force_shared_response, mem_rresp_lower};

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

        // 2. Load Memory (Unified)
        $display("--------------------------------------------------");
        $display("Loading Hex File into Unified Memory...");
        // Lưu ý: Đảm bảo DataMem_wrapper bên trong có instance RAM tên là u_DataMem.mem
        $readmemh(HEX_FILE, u_unified_mem.u_DataMem.mem); 
        $display("--------------------------------------------------");

        // 3. Scenario: Chạy bình thường
        // Core sẽ tự nạp lệnh qua L1 I-Cache -> Miss -> L2 -> Miss -> Memory
        // Sau đó chạy lệnh load/store -> L1 D-Cache -> Miss -> L2 -> ...
        $display("[SCENARIO] Running simulation...");
        
        #50000; // Chạy đủ lâu để quan sát

        $display("Simulation Finished.");
        $finish;
    end
    
    // -------------------------------------------------------------------------
    // 5. Monitor
    // -------------------------------------------------------------------------
    always @(posedge ACLK) begin
        // Monitor Read Request (Refill)
        if (axi_arvalid && axi_arready) begin
            $display("[AXI-AR] Time=%t | Addr=0x%h | ARSNOOP=%b (%s)", 
                     $time, axi_araddr, axi_arsnoop,
                     (axi_arsnoop == 4'b0000) ? "ReadNoSnoop" :
                     (axi_arsnoop == 4'b0001) ? "ReadShared" :
                     (axi_arsnoop == 4'b0010) ? "ReadClean" :
                     (axi_arsnoop == 4'b0011) ? "ReadNotSharedDirty" : 
                     (axi_arsnoop == 4'b0111) ? "ReadUnique" : 
                     (axi_arsnoop == 4'b1011) ? "CleanUnique" : "Other");
        end

        // Monitor Write Request (WriteBack)
        if (axi_awvalid && axi_awready) begin
            $display("[AXI-AW] Time=%t | Addr=0x%h | AWSNOOP=%b (%s)", 
                     $time, axi_awaddr, axi_awsnoop,
                     (axi_awsnoop == 3'b000) ? "WriteNoSnoop" :
                     (axi_awsnoop == 3'b001) ? "WriteUnique" :
                     (axi_awsnoop == 3'b011) ? "WriteBack" : "Other");
        end

        // Monitor Read Data Response
        if (axi_rvalid && axi_rready && axi_rlast) begin
            $display("[AXI-R ] Time=%t | Data=0x%h... | RRESP=%b (IsShared=%b)", 
                     $time, axi_rdata, axi_rresp, axi_rresp[2]);
        end
    end

endmodule