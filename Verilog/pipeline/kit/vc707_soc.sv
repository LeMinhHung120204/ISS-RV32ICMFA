module vc707_soc #(
    // Core Configuration
    parameter MEM_BASE      = `MEM_BASE     // Memory base address

    // Core A Instruction Memory
,   parameter CODE_A_START  = `CODE_A_START     // Core A instruction base

    // Core B Instruction Memory
,   parameter CODE_B_START  = `CODE_B_START     // Core B instruction base

    // Shared Data Memory
,   parameter DATA_START    = `DATA_START     // Shared data base

    // Cache Configuration
,   parameter NUM_WAYS      = `NUM_WAYS                 // Cache associativity
,   parameter NUM_SETS      = `NUM_SETS                 // L1 cache sets
,   parameter NUM_SETS_L2   = `NUM_SETS_L2              // L2 cache sets
,   parameter WORD_OFF_W    = `WORD_OFF_W               // Word offset (16 words/line)
,   parameter BYTE_OFF_W    = `BYTE_OFF_W               // Byte offset (4 bytes/word)
,   parameter DATA_W        = `DATA_W                   // Data width
,   parameter STRB_W        = DATA_W/8                  // Write strobe width
,   parameter LINE_W        = (1 << WORD_OFF_W) * 32    // Line width

,   parameter RAM_ADDR_W     = `RAM_ADDR_W               // Data memory address width
,   parameter RESET_VALUE    = `RESET_VALUE              // Initial value for data memory
)(
    input ACLK
,   input ARESETn

    // ==========================================
    // AXI 4 lite SLAVE INTERFACE
    // ==========================================
,   input   [3:0]               s00_axi_awaddr
,   input   [2:0]               s00_axi_awprot
,   input                       s00_axi_awvalid
,   output                      s00_axi_awready

,   input   [31:0]              s00_axi_wdata
,   input   [3:0]               s00_axi_wstrb
,   input                       s00_axi_wvalid
,   output                      s00_axi_wready

,   output  [1:0]               s00_axi_bresp
,   output                      s00_axi_bvalid
,   input                       s00_axi_bready

,   input   [3:0]               s00_axi_araddr
,   input   [2:0]               s00_axi_arprot
,   input                       s00_axi_arvalid
,   output                      s00_axi_arready

,   output  [31:0]              s00_axi_rdata
,   output  [1:0]               s00_axi_rresp
,   output                      s00_axi_rvalid
,   input                       s00_axi_rready
);

    localparam INIT_IDX_A   = (CODE_A_START - MEM_BASE) >> 2;
    localparam INIT_IDX_B   = (CODE_B_START - MEM_BASE) >> 2;
    localparam INIT_FILE_A  = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/pipeline/TestBench/tb_core/mem/hex_core_a.mem"; // File cho Core A
    localparam INIT_FILE_B  = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/pipeline/TestBench/tb_core/mem/hex_core_b.mem"; // File cho Core B

    // ==========================================
    // AXI 4 full MASTER INTERFACE
    // ==========================================
    wire [1:0]          m00_axi_awid = 2'b00;
    wire [1:0]          m00_axi_arid = 2'b00;
    
    // aw
    wire [31:0]         m00_axi_awaddr;
    wire [7:0]          m00_axi_awlen;
    wire [2:0]          m00_axi_awsize;
    wire [1:0]          m00_axi_awburst;
    wire                m00_axi_awvalid;
    wire                m00_axi_awready;

    // w
    wire [DATA_W-1:0]   m00_axi_wdata;
    wire [STRB_W-1:0]   m00_axi_wstrb;
    wire                m00_axi_wlast;
    wire                m00_axi_wvalid;
    wire                m00_axi_wready;

    // b
    wire [1:0]          m00_axi_bresp;
    wire                m00_axi_bvalid;
    wire                m00_axi_bready;
    
    // ar
    wire [31:0]         m00_axi_araddr;
    wire [7:0]          m00_axi_arlen;
    wire [2:0]          m00_axi_arsize;
    wire [1:0]          m00_axi_arburst;
    wire                m00_axi_arvalid;
    wire                m00_axi_arready;

    // r
    wire [DATA_W-1:0]   m00_axi_rdata;
    wire [1:0]          m00_axi_rresp;
    wire                m00_axi_rlast;
    wire                m00_axi_rvalid;
    wire                m00_axi_rready;

    dual_core #(
        .MEM_BASE       (MEM_BASE)
    ,   .CODE_A_START   (CODE_A_START)
    ,   .CODE_B_START   (CODE_B_START)
    ,   .DATA_START     (DATA_START)
    ,   .NUM_WAYS       (NUM_WAYS)
    ,   .NUM_SETS       (NUM_SETS)
    ,   .NUM_SETS_L2    (NUM_SETS_L2)
    ,   .WORD_OFF_W     (WORD_OFF_W)
    ,   .BYTE_OFF_W     (BYTE_OFF_W)
    ,   .DATA_W         (DATA_W)
    ,   .STRB_W         (STRB_W)
    ,   .LINE_W         (LINE_W)
    ) dual_core_inst (
        .ACLK           (ACLK)
    ,   .ARESETn        (ARESETn)

        // AXI 4 full MASTER INTERFACE
    ,   .m00_axi_awready    (m00_axi_awready)
    ,   .m00_axi_awaddr     (m00_axi_awaddr)
    ,   .m00_axi_awlen      (m00_axi_awlen)
    ,   .m00_axi_awsize     (m00_axi_awsize)
    ,   .m00_axi_awburst    (m00_axi_awburst)
    ,   .m00_axi_awvalid    (m00_axi_awvalid)

    ,   .m00_axi_wready     (m00_axi_wready)
    ,   .m00_axi_wdata      (m00_axi_wdata)
    ,   .m00_axi_wstrb      (m00_axi_wstrb)
    ,   .m00_axi_wlast      (m00_axi_wlast)
    ,   .m00_axi_wvalid     (m00_axi_wvalid)

    ,   .m00_axi_bresp      (m00_axi_bresp)
    ,   .m00_axi_bvalid     (m00_axi_bvalid)
    ,   .m00_axi_bready     (m00_axi_bready)

    ,   .m00_axi_arready    (m00_axi_arready)
    ,   .m00_axi_araddr     (m00_axi_araddr)
    ,   .m00_axi_arlen      (m00_axi_arlen)
    ,   .m00_axi_arsize     (m00_axi_arsize)
    ,   .m00_axi_arburst    (m00_axi_arburst)
    ,   .m00_axi_arvalid    (m00_axi_arvalid)


    ,   .m00_axi_rdata      (m00_axi_rdata)
    ,   .m00_axi_rresp      (m00_axi_rresp)
    ,   .m00_axi_rlast      (m00_axi_rlast)
    ,   .m00_axi_rvalid     (m00_axi_rvalid)
    ,   .m00_axi_rready     (m00_axi_rready)

        // AXI 4 lite SLAVE INTERFACE
    ,   .s00_axi_awaddr     (s00_axi_awaddr)
    ,   .s00_axi_awprot     (s00_axi_awprot)
    ,   .s00_axi_awvalid    (s00_axi_awvalid)
    ,   .s00_axi_awready    (s00_axi_awready)

    ,   .s00_axi_wdata      (s00_axi_wdata)
    ,   .s00_axi_wstrb      (s00_axi_wstrb)
    ,   .s00_axi_wvalid     (s00_axi_wvalid)
    ,   .s00_axi_wready     (s00_axi_wready)

    ,   .s00_axi_bresp      (s00_axi_bresp)
    ,   .s00_axi_bvalid     (s00_axi_bvalid)
    ,   .s00_axi_bready     (s00_axi_bready)

    ,   .s00_axi_araddr     (s00_axi_araddr)
    ,   .s00_axi_arprot     (s00_axi_arprot)
    ,   .s00_axi_arvalid    (s00_axi_arvalid)
    ,   .s00_axi_arready    (s00_axi_arready)

    ,   .s00_axi_rdata      (s00_axi_rdata)
    ,   .s00_axi_rresp      (s00_axi_rresp)
    ,   .s00_axi_rvalid     (s00_axi_rvalid)
    ,   .s00_axi_rready     (s00_axi_rready)
    );


    DataMem_wrapper #(
        .RAM_ADDR_W     (RAM_ADDR_W)
    ,   .ID_W           (0)    // Unused
    ,   .DATA_W         (DATA_W)
    ,   .RESET_VALUE    (RESET_VALUE)
    ,   .INIT_FILE_A    (INIT_FILE_A)
    ,   .INIT_FILE_B    (INIT_FILE_B)
    ,   .INIT_IDX_A     (INIT_IDX_A)
    ,   .INIT_IDX_B     (INIT_IDX_B)
    ) DataMem_wrapper_inst (
        .ACLK           (ACLK)
    ,   .ARESETn        (ARESETn)

    ,   .i_axi_awid       (/* Unused */)
    ,   .i_axi_awaddr     (m00_axi_awaddr)
    ,   .i_axi_awlen      (m00_axi_awlen)
    ,   .i_axi_awsize     (m00_axi_awsize)
    ,   .i_axi_awburst    (m00_axi_awburst)
    ,   .i_axi_awvalid    (m00_axi_awvalid)
    ,   .o_axi_awready    (m00_axi_awready)

    ,   .i_axi_wdata      (m00_axi_wdata)
    ,   .i_axi_wstrb      (m00_axi_wstrb)
    ,   .i_axi_wlast      (m00_axi_wlast)
    ,   .i_axi_wvalid     (m00_axi_wvalid)
    ,   .o_axi_wready     (m00_axi_wready)

    ,   .o_axi_bresp      (m00_axi_bresp)
    ,   .o_axi_bvalid     (m00_axi_bvalid)
    ,   .i_axi_bready     (m00_axi_bready)
    ,   .o_axi_bid        (/* Unused */)

    ,   .i_axi_arid       (m00_axi_arid)
    ,   .i_axi_araddr     (m00_axi_araddr)
    ,   .i_axi_arlen      (m00_axi_arlen)
    ,   .i_axi_arsize     (m00_axi_arsize)
    ,   .i_axi_arburst    (m00_axi_arburst)
    ,   .i_axi_arvalid    (m00_axi_arvalid)
    ,   .o_axi_arready    (m00_axi_arready)

    ,   .o_axi_rdata      (m00_axi_rdata)
    ,   .o_axi_rresp      (m00_axi_rresp)
    ,   .o_axi_rlast      (m00_axi_rlast)
    ,   .o_axi_rvalid     (m00_axi_rvalid)
    ,   .i_axi_rready     (m00_axi_rready)
    ,   .o_axi_rid        (/* Unused */)
    );
endmodule 