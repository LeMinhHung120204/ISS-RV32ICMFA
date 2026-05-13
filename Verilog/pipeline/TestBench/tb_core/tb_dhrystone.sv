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
    parameter RAM_ADDR_W    = 16;
    
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
    
    parameter integer MAX_CYCLES = 2_000_000;  // Tăng max cycle cho Dhrystone nếu cần
    parameter integer IDLE_CYCLES_THRESHOLD = 500000;
    
    // =========================================================================
    // SIGNALS
    // =========================================================================
    reg ACLK;
    reg ARESETn;
    
    // Temp memory array for loading hex
    reg [`DATA_W - 1 : 0] temp_mem [0:16383];
    
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
    integer physical_idx_b;
    integer i;

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
    // MAIN TEST PROCESS & MEMORY LOAD
    // =========================================================================
    initial begin
        string hex_file;
        
        // Nhận đường dẫn hex file (hỗ trợ truyền từ Python script)
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
        active_awaddr = 0;

        // Clear temp memory
        for (i = 0; i < 16384; i = i + 1) begin
            temp_mem[i] = 32'h0;
        end

        $display("========================================================");
        $display("DHRYSTONE TEST RUNNER");
        $display("========================================================");
        
        $readmemh(hex_file, temp_mem);

        #100;
        ARESETn = 1;
        #20;

        // Ép Core B rơi vào vòng lặp vô hạn để tránh nhiễu
        physical_idx_b = IDX_B_START % (1 << RAM_ADDR_W);
        temp_mem[physical_idx_b] = 32'h0000006F; // Lệnh RV32I: jal x0, 0
        $display("✓ Core B is locked in a loop");

        // Đổ dữ liệu vào Memory Model
        for (i = 0; i < 16384; i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = temp_mem[i];
        end
        
        $display("Memory loaded. Starting Dhrystone simulation...");
        $display("========================================================");
    end
    
    // =========================================================================
    // AXI SNOOPER FOR PASS/FAIL DETECTION
    // =========================================================================
    // Đọc liên tục Bus AXI. Khi Dhrystone code ghi vào 0xC000FFF8, kết thúc test.
    always @(posedge ACLK) begin
        if (ARESETn) begin
            // Bắt địa chỉ khi có yêu cầu ghi
            if (axi_awvalid && axi_awready) begin
                active_awaddr <= axi_awaddr;
            end

            // Kiểm tra dữ liệu khi quá trình ghi hoàn tất
            if (axi_wvalid && axi_wready) begin
                if (active_awaddr == 32'hC000FFF8) begin
                    $display("\n========================================================");
                    if (axi_wdata == 32'h00000002) begin
                        $display("BENCHMARK: STATUS_PASS");
                    end else if (axi_wdata == 32'h00000003) begin
                        $display("BENCHMARK: STATUS_FAIL");
                    end else begin
                        $display("BENCHMARK: UNKNOWN_STATUS (Wrote: %h)", axi_wdata);
                    end
                    $display("Simulation finished at cycle %0d", cycle_count);
                    $display("========================================================\n");
                    $finish;
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
            
            // Theo dõi hoạt động của Bus
            if (axi_arvalid || axi_awvalid || axi_rvalid || axi_bvalid) begin
                idle_cycle_count <= 0;
            end else begin
                idle_cycle_count <= idle_cycle_count + 1;
            end
            
            // Hủy mô phỏng nếu treo quá lâu
            if (cycle_count >= MAX_CYCLES) begin
                $display("\n[TIMEOUT] Simulation exceeded %0d cycles", MAX_CYCLES);
                $display("BENCHMARK: TIMEOUT");
                $finish;
            end
            
            // Backup nếu chạy xong mà code C không ghi vào 0xC000FFF8
            if (idle_cycle_count >= IDLE_CYCLES_THRESHOLD) begin
                $display("\n[IDLE DETECTED] No AXI activity for %0d cycles", IDLE_CYCLES_THRESHOLD);
                $display("Simulation cycles: %0d", cycle_count);
                $display("BENCHMARK: DONE (IDLE)");
                $finish;
            end
        end
    end
    
    // =========================================================================
    // ACTIVITY MONITOR (Tùy chọn hiển thị log 100k cycle/lần)
    // =========================================================================
    always @(posedge ACLK) begin
        if (ARESETn && cycle_count % 100000 == 0 && cycle_count > 0) begin
            $display("[%t] Heartbeat - Cycle: %0d", $time, cycle_count);
        end
    end
    
endmodule