`timescale 1ns/1ps

module tb_single_core;
    parameter HEX_FILE = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 
    
    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    localparam DATA_W = 32;
    localparam STRB_W = DATA_W/8;
    localparam RAM_ADDR_W = 19;
    localparam CODE_A_START = 32'h8000_0000;
    localparam CODE_B_START = 32'h8000_4000;
    localparam IDX_A_START  = (CODE_A_START - 32'h8000_0000) >> 2;
    localparam IDX_B_START  = (CODE_B_START - 32'h8000_0000) >> 2;

    reg ACLK;
    reg ARESETn;

    // --- Control Simulation ---
    // 0: Exclusive (E), 1: Shared (S)
    reg sim_force_shared_response; 

    // -------------------------------------------------------------------------
    // Unified AXI4 Interface (L2 <-> Memory)
    // -------------------------------------------------------------------------
    parameter ID_W = 2;
    parameter ADDR_W = 32;
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


    // -------------------------------------------------------------------------
    // 2. Instantiate DUT (Single Core)
    // -------------------------------------------------------------------------
    // ==========================================
    // NEW COHERENCE INTERFACE WIRES
    // 2. Instantiate DUT (Dual Core)
    // -------------------------------------------------------------------------
    dual_core #(
        .MEM_BASE       (32'h8000_0000),
        .CODE_A_START   (32'h8000_0000),
        .CODE_B_START   (32'h8000_4000),
        .DATA_START     (32'h8000_8000),
        .NUM_WAYS       (4),
        .NUM_SETS       (16),
        .NUM_SETS_L2    (64)
    ) u_dual_core (
        .ACLK               (ACLK),
        .ARESETn            (ARESETn),

        .m00_axi_awready    (axi_awready),
        .m00_axi_awaddr     (axi_awaddr),
        .m00_axi_awlen      (axi_awlen),
        .m00_axi_awsize     (axi_awsize),
        .m00_axi_awburst    (axi_awburst),
        .m00_axi_awvalid    (axi_awvalid),

        .m00_axi_wready     (axi_wready),
        .m00_axi_wdata      (axi_wdata),
        .m00_axi_wstrb      (axi_wstrb),
        .m00_axi_wlast      (axi_wlast),
        .m00_axi_wvalid     (axi_wvalid),

        .m00_axi_bresp      (axi_bresp),
        .m00_axi_bvalid     (axi_bvalid),
        .m00_axi_bready     (axi_bready),

        .m00_axi_arready    (axi_arready),
        .m00_axi_araddr     (axi_araddr),
        .m00_axi_arlen      (axi_arlen),
        .m00_axi_arsize     (axi_arsize),
        .m00_axi_arburst    (axi_arburst),
        .m00_axi_arvalid    (axi_arvalid),

        .m00_axi_rdata      (axi_rdata),
        .m00_axi_rresp      (axi_rresp),
        .m00_axi_rlast      (axi_rlast),
        .m00_axi_rvalid     (axi_rvalid),
        .m00_axi_rready     (axi_rready),

        // Tie off AXI-Lite Slave
        .s00_axi_awaddr     (4'd0),
        .s00_axi_awprot     (3'd0),
        .s00_axi_awvalid    (1'b0),
        .s00_axi_wdata      (32'd0),
        .s00_axi_wstrb      (4'd0),
        .s00_axi_wvalid     (1'b0),
        .s00_axi_bready     (1'b1),
        .s00_axi_araddr     (4'd0),
        .s00_axi_arprot     (3'd0),
        .s00_axi_arvalid    (1'b0),
        .s00_axi_rready     (1'b1)
    );

    // -------------------------------------------------------------------------
    // 3. Unified Memory Model
    // -------------------------------------------------------------------------
    wire [1:0] mem_rresp_lower;

    DataMem_wrapper2 #(
        .RAM_ADDR_W     (RAM_ADDR_W),

        .DATA_W         (DATA_W),
        .RESET_VALUE    (32'h0000_0000)
    ) u_unified_mem (
        .ACLK               (ACLK),
        .ARESETn            (ARESETn),
        
        .i_axi_awvalid      (axi_awvalid),
        .o_axi_awready      (axi_awready),
        .i_axi_awaddr       (axi_awaddr),
        .i_axi_awlen        (axi_awlen),
        .i_axi_awsize       (axi_awsize),
        .i_axi_awburst      (axi_awburst),
        
        .i_axi_wvalid       (axi_wvalid),
        .o_axi_wready       (axi_wready),
        .i_axi_wdata        (axi_wdata),
        .i_axi_wstrb        (axi_wstrb),
        .i_axi_wlast        (axi_wlast),
        
        .o_axi_bvalid       (axi_bvalid),
        .i_axi_bready       (axi_bready),
        .o_axi_bresp        (axi_bresp),
        
        .i_axi_arvalid      (axi_arvalid),
        .o_axi_arready      (axi_arready),
        .i_axi_araddr       (axi_araddr),
        .i_axi_arlen        (axi_arlen),
        .i_axi_arsize       (axi_arsize),
        .i_axi_arburst      (axi_arburst),
        
        .o_axi_rvalid       (axi_rvalid),
        .i_axi_rready       (axi_rready),
        .o_axi_rdata        (axi_rdata),
        .o_axi_rresp        (mem_rresp_lower),
        .o_axi_rlast        (axi_rlast)
    );

    assign axi_rresp = mem_rresp_lower;

    integer i;

    // -------------------------------------------------------------------------
    // 4. Simulation Process
    // -------------------------------------------------------------------------
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    initial begin
        // VCD Dump (Disabled for auto-testing)
        $dumpfile("sim.vcd");
        $dumpvars(0, tb_single_core);
    end

    // Heartbeat
    always @(posedge ACLK) begin
        if ($time % 100000 == 0) $display("Time: %0t", $time);
    end

    initial begin
        // 1. Reset
        ARESETn = 0;
        sim_force_shared_response = 0; 

        // 2. Load Memory (Unified) - Custom Loader
        $display("--------------------------------------------------");
        // Clear RAM
        for (i = 0; i < (1 << RAM_ADDR_W); i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = 32'h0;
        end

        // Nạp lệnh jump cho Core B nhảy tại chỗ (JAL x0, 0) tại 0x80004000
        u_unified_mem.u_DataMem.mem[IDX_B_START] = 32'h0000006F;

        // Nạp file hex cho Core A
        $readmemh("C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt", u_unified_mem.u_DataMem.mem, IDX_A_START);

        ARESETn = 0;
        #100; 
        ARESETn = 1;$display("Memory Loaded Successfully.");
        $display("--------------------------------------------------");

        // 3. Scenario: Chạy bình thường
        $display("[SCENARIO] Running simulation...");
        
        #2000000; 

        $display("RESULT: TIMEOUT, PC = %h", u_dual_core.core_0.u_RV32IA.D_PC);
        $finish;
    end
    // -------------------------------------------------------------------------
    // 5. Monitor
    // -------------------------------------------------------------------------
    always @(posedge ACLK) begin
        if (axi_arvalid && axi_arready) begin
            $display("[AXI-AR] Time=%t | Addr=0x%h", 
                     $time, axi_araddr);
        end

        if (axi_awvalid && axi_awready) begin
            if (axi_awaddr == 32'h80001000) begin
            end
        end
        
        if (axi_wvalid && axi_wready) begin
        end
    end

    always @(posedge ACLK) begin
        if (ARESETn) begin
            // Since the CPU doesn't support ecall (CSR/Exceptions), it treats ecall as a NOP.
            // We intercept the ecall instruction directly in the Decode stage.
            if (u_dual_core.core_0.u_RV32IA.D_Instr == 32'h00000073 && !u_dual_core.core_0.u_RV32IA.D_Flush) begin
                // Give it a small delay so gp is fully written back if it was just calculated
                #200;
                $display("========================================");
                if (u_dual_core.core_0.u_RV32IA.register_file.register[3] == 1) begin
                    $display("RESULT: PASS");
                end else begin
                    $display("RESULT: FAIL at test case %0d", u_dual_core.core_0.u_RV32IA.register_file.register[3] >> 1);
                end
                $display("========================================");
                $finish;
            end
        end
    end
    
    always @(posedge ACLK) begin
        if (axi_rvalid && axi_rready && axi_rlast) begin
            $display("[AXI-R ] Time=%t | Data=0x%h... | RRESP=%b", 
                     $time, axi_rdata, axi_rresp);
        end
    end

endmodule
