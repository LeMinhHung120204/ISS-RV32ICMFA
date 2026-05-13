`timescale 1ns/1ps
`include "define.vh"
module tb_embench;
    
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter CORE_ID       = 1'b0;
    parameter ID_W          = 2;
    parameter ADDR_W        = `ADDR_W;
    parameter DATA_W        = `DATA_W;
    parameter STRB_W        = DATA_W/8;
    parameter RAM_ADDR_W    = 16;

    // Cau hinh core
    parameter MEM_BASE      = `MEM_BASE;

    // --- VUNG CHO CORE A ---
    parameter CODE_A_START  = `CODE_A_START;
    parameter IDX_A_START   = (CODE_A_START - `MEM_BASE) >> 2;
    parameter IDX_A_END     = IDX_A_START + 4095;

    // --- VUNG CHO CORE B ---
    parameter CODE_B_START  = `CODE_B_START;
    parameter IDX_B_START   = (CODE_B_START - `MEM_BASE) >> 2; // 4096
    parameter IDX_B_END     = IDX_B_START + 4095;

    // --- DATA: CHUNG (Shared Memory) ---
    parameter DATA_START    = `DATA_START;
    
    // Default hex file (can be overridden with +HEX_FILE=...)
    parameter string DEFAULT_HEX = "D:/embench-iot/mem/aha-mont64_memory.hex";
    parameter integer MAX_CYCLES = 1_000_000;  // Max simulation cycles
    parameter integer IDLE_CYCLES_THRESHOLD = 1000;  // Detect idle/done
    
    // =========================================================================
    // SIGNALS
    // =========================================================================
    reg ACLK;
    reg ARESETn;
    reg sim_force_shared_response;
    
    // Temp memory array for loading hex
    reg [`DATA_W - 1 : 0] temp_mem [0:16383];
    // reg [7:0] temp_mem [0:65535];
    
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
    integer last_axi_activity;
    integer exit_code;
    integer test_result;
    integer physical_idx_b;
    // =========================================================================
    // INSTANTIATE DUT
    // =========================================================================
    dual_core #(
        .CODE_A_START   (CODE_A_START),
        .CODE_B_START   (CODE_B_START),
        .DATA_START     (DATA_START)
    ) u_soc_top (
        .ACLK            (ACLK),
        .ARESETn          (ARESETn),
        
        // Gộp stall của TB vào test_stall của dual_core
//        .c0_stall       (c0_stall),
//        .c1_stall       (c1_stall),

        // AW Channel
        .m00_axi_awready       (axi_awready),
        .m00_axi_awaddr        (axi_awaddr),
        .m00_axi_awlen         (axi_awlen),
        .m00_axi_awsize        (axi_awsize),
        .m00_axi_awburst       (axi_awburst),
        .m00_axi_awvalid       (axi_awvalid),

        // W Channel
        .m00_axi_wready        (axi_wready),
        .m00_axi_wdata         (axi_wdata),
        .m00_axi_wstrb         (axi_wstrb),
        .m00_axi_wlast         (axi_wlast),
        .m00_axi_wvalid        (axi_wvalid),

        // B Channel
        .m00_axi_bresp         (axi_bresp),
        .m00_axi_bvalid        (axi_bvalid),
        .m00_axi_bready        (axi_bready),

        // AR Channel
        .m00_axi_arready       (axi_arready),
        .m00_axi_araddr        (axi_araddr),
        .m00_axi_arlen         (axi_arlen),
        .m00_axi_arsize        (axi_arsize),
        .m00_axi_arburst       (axi_arburst),
        .m00_axi_arvalid       (axi_arvalid),

        // R Channel
        .m00_axi_rdata         (axi_rdata),
        .m00_axi_rresp         (axi_rresp[1:0]), // Lấy 2 bit dưới vì mem trả v? 4 bit
        .m00_axi_rlast         (axi_rlast),
        .m00_axi_rvalid        (axi_rvalid),
        .m00_axi_rready        (axi_rready)
    );
    
    // =========================================================================
    // MEMORY MODEL
    // =========================================================================
    wire [1:0] mem_rresp_lower;
    assign axi_awid = '0;
    assign axi_arid = '0;
    
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
    
    assign axi_rresp = {2'b0, mem_rresp_lower};
    
    // =========================================================================
    // CLOCK GENERATION
    // =========================================================================
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;  // 100 MHz
    end
    
    // =========================================================================
    // MAIN TEST PROCESS
    // =========================================================================
    initial begin
        string hex_file;
        integer i;
        
        // Get hex file from command line or use default
        if ($value$plusargs("HEX_FILE=%s", hex_file)) begin
            $display("Loading Core A from: %s", hex_file);
        end 
        else begin
            hex_file = DEFAULT_HEX;
            $display("Loading Core A from default: %s", hex_file);
        end
        
        // Initialize
        ARESETn = 0;
        sim_force_shared_response = 0;
        cycle_count = 0;
        idle_cycle_count = 0;
        last_axi_activity = 0;
        exit_code = -1;
        test_result = -1;
        
        // Clear temp memory
        for (i = 0; i < 16384; i = i + 1) begin
            temp_mem[i] = 32'h0;
        end
        // for (int i = 0; i < 65536; i++) temp_mem[i] = 8'h0;
        // Load hex file
        $display("========================================================");
        $display("EMBENCH-IOT TEST RUNNER");
        $display("========================================================");
        $display("Test: %s", hex_file);
        $display("Loading hex file...");
        
        $readmemh(hex_file, temp_mem);

        // --- ĐOẠN MÃ DEBUG MỚI ---
        $display("\n--- KIEM TRA 12 WORD DAU TIEN TRONG TEMP_MEM ---");
        for (i = 0; i < 12; i = i + 1) begin
            $display("Index [%0d] (Tuonng ung PC=%0d): %h", i, i*4, temp_mem[i]);
        end
        $display("------------------------------------------------\n");

        #100;
        ARESETn = 1;
        #20;
        // Pack 16x32-bit into 512-bit memory lines
        // for (i = 0; i < (1 << RAM_ADDR_W); i = i + 1) begin
        //     for (int j = 0; j < 64; j = j + 1) begin
        //         // Nạp từng byte vào vị trí tương ứng trong dòng 512-bit
        //         u_unified_mem.u_DataMem.mem[i][j*8 +: 8] = temp_mem[i*64 + j];
        //     end
        // end
        physical_idx_b = IDX_B_START % (1 << RAM_ADDR_W); // 143360 % 65536 = 12288
        
        $display("Logic Index: %0d | Truncated Physical RAM Index: %0d...", IDX_B_START, physical_idx_b);
        temp_mem[physical_idx_b] = 32'h0000006F; // Lệnh RV32I: jal x0, 0
        $display("✓ Core B is locked in a loop");

        for (i = 0; i < 16384; i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = temp_mem[i];
        end
        
        $display("Memory loaded. Starting simulation...");
        $display("========================================================");
    end
    
    // =========================================================================
    // CYCLE COUNTER & IDLE DETECTOR
    // =========================================================================
    always @(posedge ACLK) begin
        if (!ARESETn) begin
            cycle_count <= 0;
            idle_cycle_count <= 0;
            last_axi_activity <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            
            // Track AXI activity
            if (axi_arvalid || axi_awvalid || axi_rvalid || axi_bvalid) begin
                last_axi_activity <= cycle_count;
                idle_cycle_count <= 0;
            end else begin
                idle_cycle_count <= idle_cycle_count + 1;
            end
            
            // Timeout or idle detection
            if (cycle_count >= MAX_CYCLES) begin
                $display("[TIMEOUT] Simulation exceeded %d cycles", MAX_CYCLES);
                $display("RESULT: TIMEOUT");
                $finish;
            end
            
            if (idle_cycle_count >= IDLE_CYCLES_THRESHOLD) begin
                $display("[IDLE DETECTED] No AXI activity for %d cycles", IDLE_CYCLES_THRESHOLD);
                $display("Simulation cycles: %d", cycle_count);
                $display("RESULT: DONE (IDLE)");
                $finish;
            end
        end
    end
    
    // =========================================================================
    // ACTIVITY MONITOR (Optional - for debugging)
    // =========================================================================
    always @(posedge ACLK) begin
        if (ARESETn && cycle_count % 1000 == 0 && cycle_count > 0) begin
            $display("[%t] Cycle: %d | Idle: %d cycles", $time, cycle_count, idle_cycle_count);
        end
    end
    
endmodule
