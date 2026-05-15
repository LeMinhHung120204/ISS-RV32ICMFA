`timescale 1ns/1ps
`include "define.vh"

module tb_dhrystone;
    
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter CORE_ID       = 1'b0;
    parameter ID_W          = 2;
    parameter ADDR_W        = `ADDR_W;
    parameter DATA_W        = `DATA_W;
    parameter STRB_W        = DATA_W/8;
    parameter DEPTH         = 262144;    // Number of line of ram (256K words = 1MB)
    
    // Cau hinh core
    parameter MEM_BASE      = `MEM_BASE;
    
    // --- VUNG CHO CORE A ---
    parameter CODE_A_START  = `CODE_A_START;
    parameter IDX_A_START   = (CODE_A_START - `MEM_BASE) >> 2;
    parameter IDX_A_END     = IDX_A_START + 4095;
    
    // --- VUNG CHO CORE B ---
    parameter CODE_B_START  = `CODE_B_START;
    parameter IDX_B_START   = (CODE_B_START - `MEM_BASE) >> 2;
    parameter IDX_B_END     = IDX_B_START + 4095;
    
    // --- DATA: CHUNG (Shared Memory) ---
    parameter DATA_START    = `DATA_START;
    
    // Default hex file cho Dhrystone
    parameter string DEFAULT_HEX = "D:/riscv-tests/benchmarks/mem/dhrystone_memory.hex";
    
    parameter integer MAX_CYCLES = 10_000_000;  // T?ng max cycle cho Dhrystone
    parameter integer IDLE_CYCLES_THRESHOLD = 5_000_000; // T?ng c?c l?n v� khi ch?y trong Cache, AXI bus s? b? IDLE r?t l?u
    
    // =========================================================================
    // SIGNALS
    // =========================================================================
    reg ACLK;
    reg ARESETn;
    
    // Temp memory array for loading hex
    reg [`DATA_W - 1 : 0] temp_mem [0:DEPTH-1];
    
    // AXI signals
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
    
    // Test monitoring
    integer cycle_count;
    integer idle_cycle_count;
    integer start_cycle;
    integer stop_cycle;
    reg benchmark_started;
    reg benchmark_stopped;
    integer physical_idx_b;
    integer i;
    reg [31:0] prev_x6, prev_x7;

    // AXI Snooper Address
    reg [ADDR_W-1:0] active_awaddr;

    // =========================================================================
    // INSTANTIATE DUT
    // =========================================================================
    dual_core #(
        .CODE_A_START   (CODE_A_START),
        .CODE_B_START   (CODE_B_START),
        .DATA_START     (DATA_START)
    ) u_soc_top (
        .ACLK            (ACLK),
        .ARESETn         (ARESETn),

        // AW Channel
        .m00_axi_awready (axi_awready),
        .m00_axi_awaddr  (axi_awaddr),
        .m00_axi_awlen   (axi_awlen),
        .m00_axi_awsize  (axi_awsize),
        .m00_axi_awburst (axi_awburst),
        .m00_axi_awvalid (axi_awvalid),

        // W Channel
        .m00_axi_wready  (axi_wready),
        .m00_axi_wdata   (axi_wdata),
        .m00_axi_wstrb   (axi_wstrb),
        .m00_axi_wlast   (axi_wlast),
        .m00_axi_wvalid  (axi_wvalid),

        // B Channel
        .m00_axi_bresp   (axi_bresp),
        .m00_axi_bvalid  (axi_bvalid),
        .m00_axi_bready  (axi_bready),

        // AR Channel
        .m00_axi_arready (axi_arready),
        .m00_axi_araddr  (axi_araddr),
        .m00_axi_arlen   (axi_arlen),
        .m00_axi_arsize  (axi_arsize),
        .m00_axi_arburst (axi_arburst),
        .m00_axi_arvalid (axi_arvalid),

        // R Channel
        .m00_axi_rdata   (axi_rdata),
        .m00_axi_rresp   (axi_rresp[1:0]), 
        .m00_axi_rlast   (axi_rlast),
        .m00_axi_rvalid  (axi_rvalid),
        .m00_axi_rready  (axi_rready)
    );

    // =========================================================================
    // MEMORY MODEL
    // =========================================================================
    wire [1:0] mem_rresp_lower;
    assign axi_awid = '0;
    assign axi_arid = '0;
    
    DataMem_wrapper #(
        .RAM_ADDR_W ($clog2(DEPTH)),
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
    assign axi_rresp = {2'b0, mem_rresp_lower};
    
    // =========================================================================
    // CLOCK GENERATION
    // =========================================================================
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;  // 100 MHz
    end
    
    // =========================================================================
    // MAIN TEST PROCESS & MEMORY LOAD
    // =========================================================================
    initial begin
        string hex_file;
        
        // Nh?n ???ng d?n hex file (h? tr? truy?n t? Python script)
        if ($value$plusargs("HEX_A_FILE=%s", hex_file)) begin
            $display("Loading Core A from: %s", hex_file);
        end else begin
            hex_file = DEFAULT_HEX;
            $display("Loading Core A from default: %s", hex_file);
        end
        
        // Initialize
        ARESETn = 0;
        cycle_count = 0;
        idle_cycle_count = 0;
        start_cycle = 0;
        stop_cycle = 0;
        benchmark_started = 0;
        benchmark_stopped = 0;
        active_awaddr = 0;
        prev_x6 = 0;
        prev_x7 = 0;

        // Clear temp memory
        for (i = 0; i < DEPTH; i = i + 1) begin
            temp_mem[i] = 32'h0;
        end

        $display("========================================================");
        $display("DHRYSTONE TEST RUNNER");
        $display("========================================================");
        
        $readmemh(hex_file, temp_mem);

        #100;
        ARESETn = 1;
        #20;

        // �p Core B r?i v�o v�ng l?p v� h?n ?? tr�nh nhi?u
        physical_idx_b = IDX_B_START % DEPTH;
        temp_mem[physical_idx_b] = 32'h0000006F; // L?nh RV32I: jal x0, 0
        $display("? Core B is locked in a loop");

        // ?? d? li?u v�o Memory Model
        for (i = 0; i < DEPTH; i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = temp_mem[i];
        end
        
        $display("Memory loaded. Starting Dhrystone simulation...");
        $display("========================================================");
    end
    
    // =========================================================================
    // REGISTER SNOOPER FOR PASS/FAIL DETECTION
    // =========================================================================
    // Đọc liên tục thanh ghi x6 (t1).
    // 0x11111111 = timer start, 0x22222222 = timer stop, 0xBAADF00D = benchmark done.
    always @(posedge ACLK) begin
        if (ARESETn) begin
            case (u_soc_top.core_0.u_RV32IA.register_file.register[6])
                32'h11111111: begin
                    start_cycle = cycle_count;
                    benchmark_started = 1;
                    $display("BENCHMARK: START_CYCLE %0d", start_cycle);
                end
                32'h22222222: begin
                    stop_cycle = cycle_count;
                    benchmark_stopped = 1;
                    $display("BENCHMARK: STOP_CYCLE %0d", stop_cycle);
                    $display("BENCHMARK: ELAPSED_CYCLES %0d", stop_cycle - start_cycle);
                end
                32'hBAADF00D: begin
                    $display("\n========================================================");
                    $display("BENCHMARK: DONE");
                    $display("DMIPS_SCORE: 0x%h", u_soc_top.core_0.u_RV32IA.register_file.register[5]); // Read from x5
                    if (benchmark_started && benchmark_stopped) begin
                        $display("BENCHMARK: ELAPSED_CYCLES %0d", stop_cycle - start_cycle);
                    end else begin
                        $display("BENCHMARK: ELAPSED_CYCLES: UNKNOWN");
                    end
                    $display("Simulation finished at cycle %0d", cycle_count);
                    $display("========================================================\n");
                    $finish;
                end
            endcase
            
            // Theo dõi x7 (t2) cho các debug markers
            if (u_soc_top.core_0.u_RV32IA.register_file.register[7] != prev_x7) begin
                if (u_soc_top.core_0.u_RV32IA.register_file.register[7] == 32'h5A5A5A5A) begin
                    $display("[DEBUG] Boot marker 0x5A5A5A5A loaded in x7 at cycle %0d", cycle_count);
                end else if (u_soc_top.core_0.u_RV32IA.register_file.register[7] == 32'hDEADBEEF) begin
                    $display("[DEBUG] Main() entry marker 0xDEADBEEF loaded in x7 at cycle %0d", cycle_count);
                end
            end
        end
    end

    // =========================================================================
    // CYCLE COUNTER & FALLBACK TIMEOUT
    // =========================================================================
    always @(posedge ACLK) begin
        if (!ARESETn) begin
            cycle_count <= 0;
            idle_cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            
            // Theo d�i ho?t ??ng c?a Bus
            if (axi_arvalid || axi_awvalid || axi_rvalid || axi_bvalid) begin
                idle_cycle_count <= 0;
            end else begin
                idle_cycle_count <= idle_cycle_count + 1;
            end
            
            // H?y m� ph?ng n?u treo qu� l�u
            if (cycle_count >= MAX_CYCLES) begin
                $display("\n[TIMEOUT] Simulation exceeded %0d cycles", MAX_CYCLES);
                $display("BENCHMARK: TIMEOUT");
                $finish;
            end
            
            // Backup timeout (in case it didn't finish properly)
            if (idle_cycle_count >= IDLE_CYCLES_THRESHOLD) begin
                $display("\n[IDLE DETECTED] No AXI activity for %0d cycles", IDLE_CYCLES_THRESHOLD);
                $display("Simulation cycles: %0d", cycle_count);
                if (u_soc_top.core_0.u_RV32IA.register_file.register[6] == 32'hBAADF00D) begin
                    $display("\n========================================================");
                    $display("BENCHMARK: DONE (IDLE)");
                    $display("DMIPS_SCORE: 0x%h", u_soc_top.core_0.u_RV32IA.register_file.register[5]);
                    if (benchmark_started && benchmark_stopped) begin
                        $display("BENCHMARK: ELAPSED_CYCLES %0d", stop_cycle - start_cycle);
                    end else begin
                        $display("BENCHMARK: ELAPSED_CYCLES: UNKNOWN");
                    end
                    $display("Simulation finished at cycle %0d", cycle_count);
                    $display("========================================================\n");
                    $finish;
                end else begin
                    $display("BENCHMARK: IDLE_WAIT");
                    // Do not finish here; keep running until final DONE marker or timeout.
                end
            end
        end
    end
    
    // =========================================================================
    // ACTIVITY MONITOR (T�y ch?n hi?n th? log 100k cycle/l?n)
    // =========================================================================
    always @(posedge ACLK) begin
        if (ARESETn && cycle_count % 100000 == 0 && cycle_count > 0) begin
            $display("[%t] Heartbeat - Cycle: %0d", $time, cycle_count);
        end
    end
    
endmodule