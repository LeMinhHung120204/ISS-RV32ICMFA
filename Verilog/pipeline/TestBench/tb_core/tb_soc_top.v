`timescale 1ns/1ps

module tb_soc_top;
    parameter HEX_FILE = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 

    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    parameter ADDR_W        = 32;
    parameter DATA_W        = 512;
    parameter STRB_W        = DATA_W/8;
    parameter RAM_ADDR_W    = 3;

    // Core start PC parameters (two nearby addresses for easy testing)
    parameter C0_START_PC   = 32'h00000000;
    parameter C1_START_PC   = 32'h00000100;
    parameter C0_END_PC     = C0_START_PC + 32'h00000100;
    parameter C1_END_PC     = C1_START_PC + 32'h00000100;

    reg ACLK;
    reg ARESETn;

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
    wire [1:0]    m_axi_rresp;
    wire          m_axi_rlast;
    wire          m_axi_rvalid;
    wire          m_axi_rready;

    // -------------------------------------------------------------------------
    // 2. Instantiate DUT (soc_top)
    // -------------------------------------------------------------------------
    soc_top #(
        .C0_START_PC    (C0_START_PC),
        .C0_END_PC      (C0_END_PC),
        .C1_START_PC    (C1_START_PC),
        .C1_END_PC      (C1_END_PC)
    ) u_soc_top (
        .ACLK         (ACLK),
        .ARESETn      (ARESETn),

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
        .RAM_ADDR_W (RAM_ADDR_W),
        .ID_W       (2),
        .DATA_W     (DATA_W)
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
    assign m_axi_rresp = mem_rresp_lower;

    // -------------------------------------------------------------------------
    // 4. Simulation Process
    // -------------------------------------------------------------------------
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    initial begin
        ARESETn = 0;
        for (i = 0; i < 16384; i = i + 1) begin
            temp_mem[i] = 32'h0;
        end

        #100;
        ARESETn = 1;
        #20;

        $display("--------------------------------------------------");
        $display("Loading 32-bit Hex File into 512-bit Memory (soc_top TB)...");

        $readmemh(HEX_FILE, temp_mem);

        for (i = 0; i < (1 << RAM_ADDR_W); i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = {
                temp_mem[i*16 + 15],
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
                temp_mem[i*16 + 0]
            };
        end

        $display("Memory Loaded Successfully.");
        $display("--------------------------------------------------");

        $display("[SCENARIO] Running simulation...");
        #5000;

        $display("Simulation Finished.");
        $finish;
    end

    // -------------------------------------------------------------------------
    // 5. Monitor
    // -------------------------------------------------------------------------
    always @(posedge ACLK) begin
        if (m_axi_arvalid && m_axi_arready) begin
            $display("[AXI-AR] Time=%t | Addr=0x%h", $time, m_axi_araddr);
        end

        if (m_axi_awvalid && m_axi_awready) begin
            $display("[AXI-AW] Time=%t | Addr=0x%h", $time, m_axi_awaddr);
        end

        if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
            $display("[AXI-R ] Time=%t | Data=0x%h... | RRESP=%b", $time, m_axi_rdata, m_axi_rresp);
        end
    end

endmodule
