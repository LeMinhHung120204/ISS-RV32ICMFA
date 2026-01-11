`timescale 1ns/1ps

module tb_single_core;
    parameter HEX_FILE = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 
    
    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    parameter CORE_ID       = 1'b0;
    parameter ID_W          = 2;
    parameter ADDR_W        = 32;
    parameter DATA_W        = 512;
    parameter STRB_W        = DATA_W/8;
    parameter RAM_ADDR_W    = 3;

    reg ACLK;
    reg ARESETn;

    // --- Control Simulation ---
    // 0: Exclusive (E), 1: Shared (S)
    reg sim_force_shared_response; 

    // --- MODIFIED HERE: Khai báo biến tạm để load Hex ---
    // Mảng tạm 32-bit, đủ lớn để chứa toàn bộ file hex (ví dụ 64KB words)
    reg [31:0] temp_mem [0:16383]; 
    integer i;
    // ----------------------------------------------------

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
    wire [3:0]          axi_rresp; 
    
    wire                axi_bvalid, axi_bready;
    wire                axi_rlast, axi_rvalid, axi_rready;

    // ACE Signals 
    wire [2:0]          axi_awsnoop;
    wire [3:0]          axi_arsnoop;
    wire [1:0]          axi_awdomain, axi_ardomain;

    // Snoop Channels (Tie low)
    reg                 s_ace_acvalid = 0;
    reg  [ADDR_W-1:0]   s_ace_acaddr  = 0;
    reg  [3:0]          s_ace_acsnoop = 0;
    wire                s_ace_acready;

    wire                s_ace_crvalid, s_ace_cdvalid;
    wire [4:0]          s_ace_crresp;
    wire [DATA_W-1:0]   s_ace_cddata;

    // -------------------------------------------------------------------------
    // 2. Instantiate DUT (Single Core)
    // -------------------------------------------------------------------------
    single_core #(
        .CORE_ID(CORE_ID), 
        .ID_W   (ID_W), 
        .ADDR_W (ADDR_W), 
        .DATA_W (32) // Core dùng 32-bit interface
    ) u_core (
        .ACLK(ACLK), 
        .ARESETn(ARESETn),

        // --- AXI4 ACE Master Interface ---
        .m_axi_awid     (axi_awid),
        .m_axi_awaddr   (axi_awaddr),
        .m_axi_awlen    (axi_awlen),
        .m_axi_awsize   (axi_awsize),
        .m_axi_awburst  (axi_awburst),
        .m_axi_awvalid  (axi_awvalid),
        .m_axi_awready  (axi_awready),
        .m_axi_awsnoop  (axi_awsnoop),
        .m_axi_awdomain (axi_awdomain),

        .m_axi_wdata    (axi_wdata),
        .m_axi_wstrb    (axi_wstrb),
        .m_axi_wlast    (axi_wlast),
        .m_axi_wvalid   (axi_wvalid),
        .m_axi_wready   (axi_wready),

        .m_axi_bid      (axi_bid),
        .m_axi_bresp    (axi_bresp),
        .m_axi_bvalid   (axi_bvalid),
        .m_axi_bready   (axi_bready),

        .m_axi_arid     (axi_arid),
        .m_axi_araddr   (axi_araddr),
        .m_axi_arlen    (axi_arlen),
        .m_axi_arsize   (axi_arsize),
        .m_axi_arburst  (axi_arburst),
        .m_axi_arvalid  (axi_arvalid),
        .m_axi_arready  (axi_arready),
        .m_axi_arsnoop  (axi_arsnoop),
        .m_axi_ardomain (axi_ardomain),

        .m_axi_rid      (axi_rid),
        .m_axi_rdata    (axi_rdata),
        .m_axi_rresp    (axi_rresp),
        .m_axi_rlast    (axi_rlast),
        .m_axi_rvalid   (axi_rvalid),
        .m_axi_rready   (axi_rready),

        .s_ace_acvalid  (s_ace_acvalid),
        .s_ace_acaddr   (s_ace_acaddr),
        .s_ace_acsnoop  (s_ace_acsnoop),
        .s_ace_acready  (s_ace_acready),

        .s_ace_crready  (1'b1),
        .s_ace_crvalid  (s_ace_crvalid),
        .s_ace_crresp   (s_ace_crresp),
        
        .s_ace_cdready  (1'b1),
        .s_ace_cdvalid  (s_ace_cdvalid),
        .s_ace_cddata   (s_ace_cddata),
        .s_ace_cdlast   ()
    );

    // -------------------------------------------------------------------------
    // 3. Unified Memory Model
    // -------------------------------------------------------------------------
    wire [1:0] mem_rresp_lower;

    DataMem_wrapper #(
        .RAM_ADDR_W (RAM_ADDR_W), 
        .ID_W       (ID_W), 
        .DATA_W     (DATA_W)
    ) u_unified_mem (
        .ACLK           (ACLK), 
        .ARESETn        (ARESETn),
        
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
        .o_axi_rresp    (mem_rresp_lower),
        .o_axi_rlast    (axi_rlast)
    );

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
        sim_force_shared_response = 0; 
        
        // --- MODIFIED HERE: Xóa sạch temp_mem ---
        for (i = 0; i < 16384; i = i + 1) begin
            temp_mem[i] = 32'h0;
        end
        // ----------------------------------------

        #100;
        ARESETn = 1;
        #20;

        // 2. Load Memory (Unified) - Custom Loader
        $display("--------------------------------------------------");
        $display("Loading 32-bit Hex File into 512-bit Memory...");
        
        // Bước A: Load file hex 32-bit vào mảng tạm
        $readmemh(HEX_FILE, temp_mem); 

        // Bước B: Pack 16 word 32-bit thành 1 dòng 512-bit
        // Giả sử RAM có chiều sâu là 2^RAM_ADDR_W
        for (i = 0; i < (1 << RAM_ADDR_W); i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = {
                temp_mem[i*16 + 15], // MSB
                temp_mem[i*16 + 14],
                temp_mem[i*16 + 13],
                temp_mem[i*16 + 12],
                temp_mem[i*16 + 11],
                temp_mem[i*16 + 10],
                temp_mem[i*16 + 9],
                temp_mem[i*16 + 8],
                temp_mem[i*16 + 7],
                temp_mem[i*16 + 6],
                temp_mem[i*16 + 5],
                temp_mem[i*16 + 4],
                temp_mem[i*16 + 3],
                temp_mem[i*16 + 2],
                temp_mem[i*16 + 1],
                temp_mem[i*16 + 0]   // LSB (Addr 0)
            };
        end
        $display("Memory Loaded Successfully.");
        $display("--------------------------------------------------");

        // 3. Scenario: Chạy bình thường
        $display("[SCENARIO] Running simulation...");
        
        #2000; 

        $display("Simulation Finished.");
        $finish;
    end
    
    // -------------------------------------------------------------------------
    // 5. Monitor
    // -------------------------------------------------------------------------
    always @(posedge ACLK) begin
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

        if (axi_awvalid && axi_awready) begin
            $display("[AXI-AW] Time=%t | Addr=0x%h | AWSNOOP=%b (%s)", 
                     $time, axi_awaddr, axi_awsnoop,
                     (axi_awsnoop == 3'b000) ? "WriteNoSnoop" :
                     (axi_awsnoop == 3'b001) ? "WriteUnique" :
                     (axi_awsnoop == 3'b011) ? "WriteBack" : "Other");
        end

        if (axi_rvalid && axi_rready && axi_rlast) begin
            $display("[AXI-R ] Time=%t | Data=0x%h... | RRESP=%b", 
                     $time, axi_rdata, axi_rresp);
        end
    end

endmodule