`timescale 1ns/1ps
`include "define.vh"
module tb_soc_top;
    // Default hex files (can be overridden with +HEX_A_FILE=... +HEX_B_FILE=...)
    parameter HEX_FILE          = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/hexfile.txt"; 
    parameter HEX_A             = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/pipeline/TestBench/tb_core/mem/hex_core_a.txt";
    parameter HEX_B             = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/pipeline/TestBench/tb_core/mem/hex_core_b.txt";

    parameter LOG_PATH          = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/core_a_registers.log";
    parameter FINAL_LOG_PATH    = "C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/final_registers.log";
    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    parameter ADDR_W        = `ADDR_W;
    parameter DATA_W        = `DATA_W; // use 32-bit beats for TB
    parameter STRB_W        = DATA_W/8;
    parameter RAM_ADDR_W    = 3;
    parameter RESET_VALUE   = 32'h00000013; // nop

    // Cau hinh core
    parameter MEM_BASE      = `MEM_BASE;

    // --- VUNG CHO CORE A ---
    parameter CODE_A_START  = `CODE_A_START;
    parameter IDX_A_START   = CODE_A_START >> 2; // 0
    parameter IDX_A_END     = IDX_A_START + 4095;

    // --- VUNG CHO CORE B ---
    parameter CODE_B_START  = `CODE_B_START;
    parameter IDX_B_START   = CODE_B_START >> 2; // 4096
    parameter IDX_B_END     = IDX_B_START + 4095;

    // --- DATA: CHUNG (Shared Memory) ---
    parameter DATA_START    = `DATA_START;

    reg ACLK;
    reg ARESETn;
    reg c0_stall;
    reg c1_stall;

    integer i;
    integer cycle_count;
    integer idle_cycle_count;
    integer last_axi_activity;
    
    // Test parameters
    parameter integer MAX_CYCLES = 2000000;          // Max simulation cycles
    parameter integer IDLE_CYCLES_THRESHOLD = 2000;  // Detect idle/done

    // // -------------------------------------------------------------------------
    // // External AXI4 Master Interface (from soc_top)
    // // -------------------------------------------------------------------------
    // wire [1:0]    m_axi_awid;
    // wire [31:0]   m_axi_awaddr;
    // wire [7:0]    m_axi_awlen;
    // wire [2:0]    m_axi_awsize;
    // wire [1:0]    m_axi_awburst;
    // wire          m_axi_awvalid;
    // wire          m_axi_awready;

    // wire [DATA_W-1:0]  m_axi_wdata;
    // wire [STRB_W-1:0]  m_axi_wstrb;
    // wire               m_axi_wlast;
    // wire               m_axi_wvalid;
    // wire               m_axi_wready;

    // wire [1:0]    m_axi_bid;
    // wire [1:0]    m_axi_bresp;
    // wire          m_axi_bvalid;
    // wire          m_axi_bready;

    // wire [1:0]    m_axi_arid;
    // wire [31:0]   m_axi_araddr;
    // wire [7:0]    m_axi_arlen;
    // wire [2:0]    m_axi_arsize;
    // wire [1:0]    m_axi_arburst;
    // wire          m_axi_arvalid;
    // wire          m_axi_arready;

    // wire [1:0]    m_axi_rid;
    // wire [DATA_W-1:0] m_axi_rdata;
    // wire [3:0]    m_axi_rresp;
    // wire          m_axi_rlast;
    // wire          m_axi_rvalid;
    // wire          m_axi_rready;

    // // -------------------------------------------------------------------------
    // // 2. Instantiate DUT (soc_top)
    // // -------------------------------------------------------------------------
    // soc_top #(
    //     .CODE_A_START   (CODE_A_START),
    //     .CODE_B_START   (CODE_B_START),
    //     .DATA_START     (DATA_START)
    // ) u_soc_top (
    //     .ACLK           (ACLK),
    //     .ARESETn        (ARESETn),
    //     .c0_stall       (c0_stall),
    //     .c1_stall       (c1_stall),

    //     .m_axi_awid     (m_axi_awid),
    //     .m_axi_awaddr   (m_axi_awaddr),
    //     .m_axi_awlen    (m_axi_awlen),
    //     .m_axi_awsize   (m_axi_awsize),
    //     .m_axi_awburst  (m_axi_awburst),
    //     .m_axi_awvalid  (m_axi_awvalid),
    //     .m_axi_awready  (m_axi_awready),

    //     .m_axi_wdata    (m_axi_wdata),
    //     .m_axi_wstrb    (m_axi_wstrb),
    //     .m_axi_wlast    (m_axi_wlast),
    //     .m_axi_wvalid   (m_axi_wvalid),
    //     .m_axi_wready   (m_axi_wready),

    //     .m_axi_bid      (m_axi_bid),
    //     .m_axi_bresp    (m_axi_bresp),
    //     .m_axi_bvalid   (m_axi_bvalid),
    //     .m_axi_bready   (m_axi_bready),

    //     .m_axi_arid     (m_axi_arid),
    //     .m_axi_araddr   (m_axi_araddr),
    //     .m_axi_arlen    (m_axi_arlen),
    //     .m_axi_arsize   (m_axi_arsize),
    //     .m_axi_arburst  (m_axi_arburst),
    //     .m_axi_arvalid  (m_axi_arvalid),
    //     .m_axi_arready  (m_axi_arready),

    //     .m_axi_rid      (m_axi_rid),
    //     .m_axi_rdata    (m_axi_rdata),
    //     .m_axi_rresp    (m_axi_rresp),
    //     .m_axi_rlast    (m_axi_rlast),
    //     .m_axi_rvalid   (m_axi_rvalid),
    //     .m_axi_rready   (m_axi_rready)
    // );

    // -------------------------------------------------------------------------
    // External AXI4 Master Interface (from soc_top)
    // -------------------------------------------------------------------------
    // dual_core hiện tại không hỗ trợ AXI ID, nên ta gán cứng = 0
    wire [1:0]    m_axi_awid = 2'b00;
    wire [1:0]    m_axi_arid = 2'b00;

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
        .m00_axi_awready       (m_axi_awready),
        .m00_axi_awaddr        (m_axi_awaddr),
        .m00_axi_awlen         (m_axi_awlen),
        .m00_axi_awsize        (m_axi_awsize),
        .m00_axi_awburst       (m_axi_awburst),
        .m00_axi_awvalid       (m_axi_awvalid),

        // W Channel
        .m00_axi_wready        (m_axi_wready),
        .m00_axi_wdata         (m_axi_wdata),
        .m00_axi_wstrb         (m_axi_wstrb),
        .m00_axi_wlast         (m_axi_wlast),
        .m00_axi_wvalid        (m_axi_wvalid),

        // B Channel
        .m00_axi_bresp         (m_axi_bresp),
        .m00_axi_bvalid        (m_axi_bvalid),
        .m00_axi_bready        (m_axi_bready),

        // AR Channel
        .m00_axi_arready       (m_axi_arready),
        .m00_axi_araddr        (m_axi_araddr),
        .m00_axi_arlen         (m_axi_arlen),
        .m00_axi_arsize        (m_axi_arsize),
        .m00_axi_arburst       (m_axi_arburst),
        .m00_axi_arvalid       (m_axi_arvalid),

        // R Channel
        .m00_axi_rdata         (m_axi_rdata),
        .m00_axi_rresp         (m_axi_rresp[1:0]), // Lấy 2 bit dưới vì mem trả v? 4 bit
        .m00_axi_rlast         (m_axi_rlast),
        .m00_axi_rvalid        (m_axi_rvalid),
        .m00_axi_rready        (m_axi_rready)
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
            if (m_axi_arvalid || m_axi_awvalid || m_axi_rvalid || m_axi_bvalid) begin
                last_axi_activity <= cycle_count;
                idle_cycle_count <= 0;
            end else begin
                idle_cycle_count <= idle_cycle_count + 1;
            end
            
            // Timeout detection
            if (cycle_count >= MAX_CYCLES) begin
                $display("[TIMEOUT] Simulation exceeded %d cycles", MAX_CYCLES);
                $display("RESULT: TIMEOUT");
                $finish;
            end
            
            // Idle detection (program done)
            if (idle_cycle_count >= IDLE_CYCLES_THRESHOLD && cycle_count > 1000) begin
                $display("[IDLE DETECTED] No AXI activity for %d cycles", IDLE_CYCLES_THRESHOLD);
                $display("Total simulation cycles: %d", cycle_count);
                $display("RESULT: DONE (IDLE)");
                #100;  // Wait a bit for final logs to write
                $finish;
            end
        end
    end
    
    // =========================================================================
    // ACTIVITY MONITOR (Optional - for debugging)
    // =========================================================================
    always @(posedge ACLK) begin
        if (ARESETn && cycle_count % 5000 == 0 && cycle_count > 0) begin
            $display("[%t] Cycle: %d | Idle: %d cycles", $time, cycle_count, idle_cycle_count);
        end
    end

    // integer r;
    // always @(posedge ACLK) begin
    //     if (ARESETn) begin
    //         $display("\n--- Cycle: %t | Core A Registers ---", $time);
    //         for (r = 0; r < 32; r = r + 1) begin
    //             $display("x%02d: %h", r, u_soc_top.core_0.u_RV32IA.register_file.register[r]);
    //         end
    //         $display("---------------------------------------");
    //     end
    // end

    // --- Khai báo biến (�?ặt ở đầu module hoặc trước các block initial/always) ---
    integer final_reg_log;
    integer reg_log;
    integer r_idx;
    integer k;

    reg [31:0] prev_regs [0:31];
    // --- Khởi tạo file log ---
    initial begin
        reg_log = $fopen(LOG_PATH, "w");
        if (reg_log == 0) begin
            $display("ERROR: Khong the mo file log tai: %s", LOG_PATH);
            $finish;
        end
    end
    
    initial begin
        for (k = 0; k < 32; k = k + 1) begin
            prev_regs[k] = 32'd0; 
        end
    end

    initial begin
        reg_log         = $fopen(LOG_PATH, "w");
        final_reg_log   = $fopen(FINAL_LOG_PATH, "w"); // Mở file log cuối cùng
        
        if (reg_log == 0 || final_reg_log == 0) begin
            $display("ERROR: Khong the mo file log!");
            $finish;
        end
    end

    // --- Ghi dữ liệu mỗi chu kỳ ---
    always @(posedge ACLK) begin
        if (ARESETn) begin
            #10; 
            for (r_idx = 0; r_idx < 32; r_idx = r_idx + 1) begin
                // Kiểm tra xem giá trị hiện tại có khác với giá trị chu kỳ trước không
                if (u_soc_top.core_0.u_RV32IA.register_file.register[r_idx] !== prev_regs[r_idx]) begin
                    
                    $fdisplay(reg_log, "[Time: %t] x%02d: %h -> %h", 
                        $time, 
                        r_idx, 
                        prev_regs[r_idx], // Giá trị cũ
                        u_soc_top.core_0.u_RV32IA.register_file.register[r_idx] // Giá trị mới
                    );

                    // Cập nhật lại giá trị cũ bằng giá trị mới để so sánh cho chu kỳ sau
                    prev_regs[r_idx] = u_soc_top.core_0.u_RV32IA.register_file.register[r_idx];
                end
            end
        end
    end

    initial begin
        string hex_a_file;
        string hex_b_file;
        
        ARESETn     = 0;
        for (i = 0; i < (1 << RAM_ADDR_W); i = i + 1) begin
            u_unified_mem.u_DataMem.mem[i] = 32'h0;
        end

        #100;
        ARESETn     = 1;

        $display("========================================================");
        $display("EMBENCH-IoT TEST RUNNER (DUAL CORE SOC)");
        $display("========================================================");

        // Get hex files from command line or use defaults
        if (!$value$plusargs("HEX_A_FILE=%s", hex_a_file)) begin
            hex_a_file = HEX_A;
        end
        
        if (!$value$plusargs("HEX_B_FILE=%s", hex_b_file)) begin
            hex_b_file = HEX_B;
        end
        
        $display("Core A hex file: %s", hex_a_file);
        $display("Core B hex file: %s", hex_b_file);
        $display("--------------------------------------------------");

        // Load Core A program
        if (hex_a_file != "") begin
            $display("Loading Core A at 0x%h...", CODE_A_START);
            $readmemh(hex_a_file, u_unified_mem.u_DataMem.mem, IDX_A_START, IDX_A_END);
            $display("✓ Core A loaded successfully");
        end else begin
            $display("⚠ Core A hex file not provided");
        end

        // Load Core B program (if provided)
        if (hex_b_file != "" && hex_b_file != hex_a_file) begin
            $display("Loading Core B at 0x%h...", CODE_B_START);
            $readmemh(hex_b_file, u_unified_mem.u_DataMem.mem, IDX_B_START, IDX_B_END);
            $display("✓ Core B loaded successfully");
        end else begin
            $display("⚠ Core B disabled (same as Core A or not provided)");
        end

        $display("========================================================");
        $display("[SCENARIO] Cores starting...");
        $display("========================================================");

        #15000; 
        $display("\nSimulation Finished.");
        $display("Writing final register values to log...");
        $fdisplay(final_reg_log, "--- FINAL REGISTER VALUES AT %t ---", $time);
        $fdisplay(final_reg_log, "---------------------------------------");
        
        for (i = 0; i < 32; i = i + 1) begin
            $fdisplay(final_reg_log, "x%02d: %h", i, u_soc_top.core_0.u_RV32IA.register_file.register[i]);
        end
        
        $fdisplay(final_reg_log, "---------------------------------------");
        
        $display("Simulation Finished.");

        $fclose(reg_log);
        $fclose(final_reg_log);
        $finish;
    end

    initial begin
        c1_stall    = 0;
        c0_stall    = 0;
        
        // #1000;
        // c1_stall    = 0;
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