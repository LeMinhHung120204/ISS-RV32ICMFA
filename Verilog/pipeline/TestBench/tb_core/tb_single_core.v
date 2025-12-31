`timescale 1ns/1ps

module tb_single_core;
    parameter HEX_FILE = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 

    // -------------------------------------------------------------------------
    // 1. Parameters
    // -------------------------------------------------------------------------
    parameter CORE_ID    = 1'b0;
    parameter ID_W       = 2;
    parameter ADDR_W     = 32;
    parameter DATA_W     = 32;
    parameter RAM_ADDR_W = 5;

    reg ACLK;
    reg ARESETn;

    // Interfaces
    wire [ID_W-1:0]     d_axi_awid, d_axi_bid, d_axi_arid, d_axi_rid;
    wire [ADDR_W-1:0]   d_axi_awaddr, d_axi_araddr;
    wire [7:0]          d_axi_awlen, d_axi_arlen;
    wire [2:0]          d_axi_awsize, d_axi_arsize;
    wire [1:0]          d_axi_awburst, d_axi_arburst;
    wire                d_axi_awvalid, d_axi_awready;
    wire [DATA_W-1:0]   d_axi_wdata, d_axi_rdata;
    wire [DATA_W/8-1:0] d_axi_wstrb;
    wire                d_axi_wlast, d_axi_wvalid, d_axi_wready;
    wire [1:0]          d_axi_bresp, d_axi_rresp;
    wire                d_axi_bvalid, d_axi_bready;
    wire                d_axi_rlast, d_axi_rvalid, d_axi_rready;

    wire [ID_W-1:0]     i_axi_arid, i_axi_rid;
    wire [ADDR_W-1:0]   i_axi_araddr;
    wire [7:0]          i_axi_arlen;
    wire [2:0]          i_axi_arsize;
    wire [1:0]          i_axi_arburst;
    wire                i_axi_arvalid, i_axi_arready;
    wire [DATA_W-1:0]   i_axi_rdata;
    wire [1:0]          i_axi_rresp;
    wire                i_axi_rlast, i_axi_rvalid, i_axi_rready;

    // ACE Tie-offs
    wire [2:0]          m_d_ace_awsnoop;
    wire [1:0]          m_d_ace_awdomain, m_d_ace_awbar;
    wire [3:0]          m_d_ace_arsnoop;
    wire [1:0]          m_d_ace_ardomain, m_d_ace_arbar;
    wire                m_ace_crvalid, m_ace_cdvalid, m_ace_cdlast;
    wire [4:0]          m_ace_crresp;
    wire [DATA_W-1:0]   m_ace_cddata;
    wire                m_ace_acready;


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

        // D-Cache AXI
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
        .m_d_axi_rresp      (d_axi_rresp), 
        .m_d_axi_rlast      (d_axi_rlast), 
        .m_d_axi_rvalid     (d_axi_rvalid), 
        .m_d_axi_rready     (d_axi_rready),
        
        // ACE Tie-offs (Important for Single Core)
        .m_ace_acvalid  (1'b0), 
        .m_ace_acaddr   ({ADDR_W{1'b0}}), 
        .m_ace_acsnoop  (4'b0), 
        .m_ace_acready  (m_ace_acready),
        .m_ace_crready  (1'b1), 
        .m_ace_crvalid  (m_ace_crvalid), 
        .m_ace_crresp   (m_ace_crresp),
        .m_ace_cdready  (1'b1), 
        .m_ace_cdvalid  (m_ace_cdvalid), 
        .m_ace_cddata   (m_ace_cddata), 
        .m_ace_cdlast   (m_ace_cdlast),
        // Unused outputs
        .m_d_ace_awsnoop    (m_d_ace_awsnoop), 
        .m_d_ace_awdomain   (m_d_ace_awdomain), 
        .m_d_ace_awbar      (m_d_ace_awbar),
        .m_d_ace_arsnoop    (m_d_ace_arsnoop), 
        .m_d_ace_ardomain   (m_d_ace_ardomain), 
        .m_d_ace_arbar      (m_d_ace_arbar),

        // I-Cache AXI
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

    // INSTRUCTION RAM
    DataMem_wrapper #(
        .WIDTH_ADDR     (RAM_ADDR_W), 
        .ID_W           (ID_W), 
        .DATA_W         (DATA_W)
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
        // Tie off write ports
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


    DataMem_wrapper #(
        .WIDTH_ADDR (RAM_ADDR_W), 
        .ID_W       (ID_W), 
        .DATA_W     (DATA_W)
    ) u_d_mem (
        .ACLK(ACLK), 
        .ARESETn(ARESETn),
        .i_axi_awvalid  (d_axi_awvalid), 
        .o_axi_awready  (d_axi_awready), 
        .i_axi_awid     (d_axi_awid), 
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
        .o_axi_rresp    (d_axi_rresp), 
        .o_axi_rlast    (d_axi_rlast)
    );

    // -------------------------------------------------------------------------
    // 3. Logic Simulation & Load File
    // -------------------------------------------------------------------------
    
    // Clock Gen
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    // Main Process
    initial begin
        // 1. Reset Phase
        ARESETn = 0;
        #100;
        ARESETn = 1;
        #20;

        // 2. LOAD MACHINE CODE FROM FILE
        $display("--------------------------------------------------");
        $display("Loading Hex File: %s", HEX_FILE);

        // nap file hex vao Instruction Memory
        $readmemh(HEX_FILE, u_i_mem.u_DataMem.mem);
        
        // Debug check: in thu 2 dia chi dau tien
        $display("Check Addr 0: %h", u_i_mem.u_DataMem.mem[0]);
        $display("Check Addr 1: %h", u_i_mem.u_DataMem.mem[1]);
        $display("--------------------------------------------------");

        // 3. Run Simulation
        #5000;
        $display("Simulation Finished.");
        $finish;
    end
    
    // Monitor
    initial begin
        $monitor("Time=%t | PC=0x%h | Instr=0x%h | WrVal=%b | WrData=0x%h", 
                 $time, i_axi_araddr, i_axi_rdata, (d_axi_wvalid & d_axi_wready), d_axi_wdata);
    end

    initial begin
        #6000;
        $finish;
    end
endmodule