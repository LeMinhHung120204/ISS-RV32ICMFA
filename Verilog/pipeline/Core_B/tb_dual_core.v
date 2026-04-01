`timescale 1ns/1ps
//==============================================================================
// Testbench cho Dual Core SoC
//==============================================================================
// File: tb_dual_core.v
// Mục đích: Test cơ bản cho hệ thống Dual Core
//
// Cách chạy trên ModelSim:
//   1. Tạo project, add tất cả source files
//   2. Compile all
//   3. vsim work.tb_dual_core
//   4. run -all
//==============================================================================

module tb_dual_core;

    //==========================================================================
    // PARAMETERS
    //==========================================================================
    parameter CLK_PERIOD = 10;  // 100MHz

    //==========================================================================
    // SIGNALS
    //==========================================================================
    reg clk;
    reg rst_n;
    
    // L3 interface
    wire [31:0]  m_l3_araddr;
    wire         m_l3_arvalid;
    reg          m_l3_arready;
    reg  [511:0] m_l3_rdata;
    reg          m_l3_rvalid;
    reg          m_l3_rlast;
    wire         m_l3_rready;

    //==========================================================================
    // DUT INSTANTIATION
    //==========================================================================
    soc_dual_core u_soc (
        .ACLK           (clk),
        .ARESETn        (rst_n),
        
        .m_l3_araddr    (m_l3_araddr),
        .m_l3_arvalid   (m_l3_arvalid),
        .m_l3_arready   (m_l3_arready),
        .m_l3_rdata     (m_l3_rdata),
        .m_l3_rvalid    (m_l3_rvalid),
        .m_l3_rlast     (m_l3_rlast),
        .m_l3_rready    (m_l3_rready)
    );

    //==========================================================================
    // CLOCK GENERATION
    //==========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //==========================================================================
    // L3 MOCK (Tạm thời)
    //==========================================================================
    // Đây là mock đơn giản cho L3
    // Khi bạn của bạn hoàn thành L3, thay bằng L3 thật
    
    initial begin
        m_l3_arready = 1'b1;
        m_l3_rdata   = 512'd0;
        m_l3_rvalid  = 1'b0;
        m_l3_rlast   = 1'b0;
    end
    
    // Simple L3 response: trả về NOP instruction cho mọi request
    always @(posedge clk) begin
        if (m_l3_arvalid && m_l3_arready) begin
            // Trả về sau 2 cycles
            #(CLK_PERIOD * 2);
            m_l3_rdata  <= {16{32'h00000013}};  // 16 NOP (ADDI x0, x0, 0)
            m_l3_rvalid <= 1'b1;
            m_l3_rlast  <= 1'b1;
            
            @(posedge clk);
            while (!m_l3_rready) @(posedge clk);
            
            m_l3_rvalid <= 1'b0;
            m_l3_rlast  <= 1'b0;
        end
    end

    //==========================================================================
    // TEST SEQUENCE
    //==========================================================================
    initial begin
        // Waveform dump cho ModelSim/GTKWave
        $dumpfile("tb_dual_core.vcd");
        $dumpvars(0, tb_dual_core);
        
        $display("==============================================");
        $display("  Dual Core Testbench Start");
        $display("==============================================");
        
        // Reset
        rst_n = 0;
        $display("[%0t] Asserting reset...", $time);
        
        #(CLK_PERIOD * 10);
        rst_n = 1;
        $display("[%0t] Reset released", $time);
        
        // Chờ hệ thống chạy một lúc
        #(CLK_PERIOD * 500);
        
        // In trạng thái
        $display("\n[%0t] === Core A Status ===", $time);
        $display("  PC = 0x%h", u_soc.u_core_A.u_RV32IMF.F_PC);
        $display("  I-Cache stall = %b", u_soc.u_core_A.icache_stall);
        $display("  D-Cache stall = %b", u_soc.u_core_A.dcache_stall);
        
        $display("\n[%0t] === Core B Status ===", $time);
        $display("  PC = 0x%h", u_soc.u_core_B.u_RV32IMF.F_PC);
        $display("  I-Cache stall = %b", u_soc.u_core_B.icache_stall);
        $display("  D-Cache stall = %b", u_soc.u_core_B.dcache_stall);
        
        $display("\n[%0t] === ACE Interconnect ===", $time);
        $display("  L3 AR valid = %b", m_l3_arvalid);
        $display("  L3 AR addr  = 0x%h", m_l3_araddr);
        
        #(CLK_PERIOD * 100);
        
        $display("\n==============================================");
        $display("  Testbench Complete");
        $display("==============================================");
        $finish;
    end
    
    // Timeout
    initial begin
        #(CLK_PERIOD * 10000);
        $display("[ERROR] Timeout!");
        $finish;
    end

    //==========================================================================
    // MONITOR SIGNALS
    //==========================================================================
    // In khi có snoop activity
    always @(posedge clk) begin
        if (u_soc.c0_acvalid)
            $display("[%0t] SNOOP -> Core A: addr=0x%h", $time, u_soc.c0_acaddr);
        if (u_soc.c1_acvalid)
            $display("[%0t] SNOOP -> Core B: addr=0x%h", $time, u_soc.c1_acaddr);
        if (u_soc.c0_crvalid)
            $display("[%0t] Core A CR response: DataTransfer=%b", $time, u_soc.c0_crresp[3]);
        if (u_soc.c1_crvalid)
            $display("[%0t] Core B CR response: DataTransfer=%b", $time, u_soc.c1_crresp[3]);
    end

endmodule
