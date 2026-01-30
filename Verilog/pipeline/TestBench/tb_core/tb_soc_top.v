`timescale 1ns/1ps

module tb_soc_top;
    parameter HEX_FILE = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 
    parameter HEX_A = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/pipeline/TestBench/tb_core/mem/hex_core_a.txt";
    parameter HEX_B = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/pipeline/TestBench/tb_core/mem/hex_core_b.txt";
    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    parameter ADDR_W        = 32;
    parameter DATA_W        = 32; // use 32-bit beats for TB
    parameter STRB_W        = DATA_W/8;
    parameter RAM_ADDR_W    = 14;
    parameter RESET_VALUE   = 32'h00000013; // nop

    // Cau hinh core
    parameter MEM_BASE      = 32'h0000_0000;

    // --- VUNG CHO CORE A ---
    parameter CODE_A_START  = 32'h0000_0000;
    parameter CODE_A_END    = 32'h0000_3FFF; 
    parameter DATA_A_START  = 32'h0000_4000;
    parameter DATA_A_END    = 32'h0000_7FFF; 

    // --- VUNG CHO CORE B ---
    parameter CODE_B_START  = 32'h0000_8000;
    parameter CODE_B_END    = 32'h0000_BFFF; 
    parameter DATA_B_START  = 32'h0000_C000;
    parameter DATA_B_END    = 32'h0000_FFFF; 

    // --- VUNG DUNG CHUNG (SHARED) ---
    parameter SHARED_START  = 32'h0001_0000;
    parameter SHARED_END    = 32'h0001_7FFF; 

    reg ACLK;
    reg ARESETn;
    reg c0_stall;
    reg c1_stall;

    reg [31:0] temp_mem [0:16383];
    integer i;

    // -------------------------------------------------------------------------
    // External AXI4 Master Interface (from soc_top)
    // -------------------------------------------------------------------------
    wire [1:0]    m_axi_awid;
    wire [31:0]   m_axi_awaddr;
    wire [7:0]    m_axi_awlen;
    wire [2:0]    m_axi_awsize;
    wire [1:0]    m_axi_awburst;
    wire          m_axi_awvalid;
    wire          m_axi_awready;

    wire [DATA_W-1:0]  m_axi_wdata;
    wire [STRB_W-1:0]  m_axi_wstrb;
    wire               m_axi_wlast;
    wire               m_axi_wvalid;
    wire               m_axi_wready;

    wire [1:0]    m_axi_bid;
    wire [1:0]    m_axi_bresp;
    wire          m_axi_bvalid;
    wire          m_axi_bready;

    wire [1:0]    m_axi_arid;
    wire [31:0]   m_axi_araddr;
    wire [7:0]    m_axi_arlen;
    wire [2:0]    m_axi_arsize;
    wire [1:0]    m_axi_arburst;
    wire          m_axi_arvalid;
    wire          m_axi_arready;

    wire [1:0]    m_axi_rid;
    wire [DATA_W-1:0] m_axi_rdata;
    wire [3:0]    m_axi_rresp;
    wire          m_axi_rlast;
    wire          m_axi_rvalid;
    wire          m_axi_rready;

    // -------------------------------------------------------------------------
    // 2. Instantiate DUT (soc_top)
    // -------------------------------------------------------------------------
    soc_top #(
        .CODE_A_START     (CODE_A_START),
        .CODE_A_END       (CODE_A_END),
        .DATA_A_START     (DATA_A_START),
        .DATA_A_END       (DATA_A_END),
        .CODE_B_START     (CODE_B_START),
        .CODE_B_END       (CODE_B_END),
        .DATA_B_START     (DATA_B_START),
        .DATA_B_END       (DATA_B_END),
        .SHARED_START     (SHARED_START),
        .SHARED_END       (SHARED_END)
    ) u_soc_top (
        .ACLK         (ACLK),
        .ARESETn      (ARESETn),
        .c0_stall     (c0_stall),
        .c1_stall     (c1_stall),

        .m_axi_awid   (m_axi_awid),
        .m_axi_awaddr (m_axi_awaddr),
        .m_axi_awlen  (m_axi_awlen),
        .m_axi_awsize (m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),

        .m_axi_wdata  (m_axi_wdata),
        .m_axi_wstrb  (m_axi_wstrb),
        .m_axi_wlast  (m_axi_wlast),
        .m_axi_wvalid (m_axi_wvalid),
        .m_axi_wready (m_axi_wready),

        .m_axi_bid    (m_axi_bid),
        .m_axi_bresp  (m_axi_bresp),
        .m_axi_bvalid (m_axi_bvalid),
        .m_axi_bready (m_axi_bready),

        .m_axi_arid   (m_axi_arid),
        .m_axi_araddr (m_axi_araddr),
        .m_axi_arlen  (m_axi_arlen),
        .m_axi_arsize (m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),

        .m_axi_rid    (m_axi_rid),
        .m_axi_rdata  (m_axi_rdata),
        .m_axi_rresp  (m_axi_rresp),
        .m_axi_rlast  (m_axi_rlast),
        .m_axi_rvalid (m_axi_rvalid),
        .m_axi_rready (m_axi_rready)
    );

    // -------------------------------------------------------------------------
    // 3. Unified Memory Model (connect to soc_top external AXI)
    // -------------------------------------------------------------------------
    wire [1:0] mem_rresp_lower;

    DataMem_wrapper #(
        .RAM_ADDR_W     (RAM_ADDR_W),
        .ID_W           (2),
        .DATA_W         (DATA_W),
        .RESET_VALUE    (RESET_VALUE)
    ) u_unified_mem (
        .ACLK           (ACLK),
        .ARESETn        (ARESETn),

        .i_axi_awid     (m_axi_awid),
        .i_axi_awvalid  (m_axi_awvalid),
        .o_axi_awready  (m_axi_awready),
        .i_axi_awaddr   (m_axi_awaddr),
        .i_axi_awlen    (m_axi_awlen),
        .i_axi_awsize   (m_axi_awsize),
        .i_axi_awburst  (m_axi_awburst),

        .i_axi_wvalid   (m_axi_wvalid),
        .o_axi_wready   (m_axi_wready),
        .i_axi_wdata    (m_axi_wdata),
        .i_axi_wstrb    (m_axi_wstrb),
        .i_axi_wlast    (m_axi_wlast),

        .o_axi_bvalid   (m_axi_bvalid),
        .i_axi_bready   (m_axi_bready),
        .o_axi_bid      (m_axi_bid),
        .o_axi_bresp    (m_axi_bresp),

        .i_axi_arvalid  (m_axi_arvalid),
        .o_axi_arready  (m_axi_arready),
        .i_axi_arid     (m_axi_arid),
        .i_axi_araddr   (m_axi_araddr),
        .i_axi_arlen    (m_axi_arlen),
        .i_axi_arsize   (m_axi_arsize),
        .i_axi_arburst  (m_axi_arburst),

        .o_axi_rvalid   (m_axi_rvalid),
        .i_axi_rready   (m_axi_rready),
        .o_axi_rid      (m_axi_rid),
        .o_axi_rdata    (m_axi_rdata),
        .o_axi_rresp    (mem_rresp_lower),
        .o_axi_rlast    (m_axi_rlast)
    );

    // soc_top expects 2-bit rresp
    assign m_axi_rresp = {2'b00, mem_rresp_lower};

    // -------------------------------------------------------------------------
    // 4. Simulation Process
    // -------------------------------------------------------------------------
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    initial begin
        ARESETn     = 0;
        c0_stall    = 0;
        c1_stall    = 0;
        for (i = 0; i < (1 << RAM_ADDR_W); i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = 32'h0;
        end

        #100;
        ARESETn     = 1;

        $display("--------------------------------------------------");
        $display("Loading Multi-Core Hex Files...");

        // 2. Nap file cho Core A vào địa chỉ 0x0000
        $readmemh(HEX_A, u_unified_mem.u_DataMem.mem, 0, 2047); 

        // 3. Nap file cho Core B vào địa chỉ 0x8000
        $readmemh(HEX_B, u_unified_mem.u_DataMem.mem, 8192, 12287);

        $display("Core A loaded at 0x0000 (Index 0)");
        $display("Core B loaded at 0x8000 (Index 8192)");
        $display("--------------------------------------------------");

        $display("[SCENARIO] Both cores starting...");
        c0_stall = 0;
        c1_stall = 0;

        #2000; 
        $display("Simulation Finished.");
        $finish;
    end

    // -------------------------------------------------------------------------
    // 5. Monitor
    // -------------------------------------------------------------------------
    always @(posedge ACLK) begin
        if (m_axi_arvalid && m_axi_arready) begin
            if (m_axi_araddr < 32'h8000)
                $display("[AXI-AR] Core A Access | Addr=0x%h", m_axi_araddr);
            else
                $display("[AXI-AR] Core B Access | Addr=0x%h", m_axi_araddr);
        end
    end

endmodule
