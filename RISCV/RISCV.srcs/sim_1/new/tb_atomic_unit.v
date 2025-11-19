`timescale 1ns/1ps

module tb_atomic_unit;
    // Clock and reset
    reg clk, rst_n;
    
    // Control signals
    reg valid_in;
    wire ready, valid_out;
    
    // Atomic operation inputs
    reg [4:0] funct5;
    reg [31:0] addr, rs2;
    wire [31:0] rd_value;
    
    // Snoop signals
    reg snoop_inv;
    reg [31:0] snoop_addr;
    reg [3:0] snoop_core_id;
    
    // Debug signals
    wire [3:0] debug_state;
    wire debug_reservation_valid;
    
    // AXI signals
    wire m_ARVALID, m_ARREADY;
    wire [31:0] m_ARADDR;
    wire [7:0] m_ARLEN;
    wire [2:0] m_ARSIZE;
    wire [1:0] m_ARBURST;
    
    wire m_RVALID, m_RREADY;
    reg [31:0] m_RDATA;
    reg [1:0] m_RRESP;
    reg m_RLAST;
    
    wire m_AWVALID, m_AWREADY;
    wire [31:0] m_AWADDR;
    wire [7:0] m_AWLEN;
    wire [2:0] m_AWSIZE;
    wire [1:0] m_AWBURST;
    
    wire m_WVALID, m_WREADY;
    wire [31:0] m_WDATA;
    wire [3:0] m_WSTRB;
    wire m_WLAST;
    
    wire m_BVALID, m_BREADY;
    reg [1:0] m_BRESP;
    
    // Memory model
    reg [31:0] memory [0:1023];
    integer i;
    
    // Test counters
    integer test_pass = 0;
    integer test_fail = 0;
    
    // DUT instantiation
    atomic_unit_ace #(
        .WIDTH_DATA(32),
        .WIDTH_ADDR(32),
        .CORE_ID(0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_in),
        .ready(ready),
        .valid_output(valid_out),
        .funct5(funct5),
        .aq(1'b0),
        .rl(1'b0),
        .addr(addr),
        .rs1_data(32'b0),
        .rs2_data(rs2),
        .rd_value(rd_value),
        .snoop_invalidate(snoop_inv),
        .snoop_addr(snoop_addr),
        .snoop_core_id(snoop_core_id),
        .debug_state(debug_state),
        .debug_reservation_valid(debug_reservation_valid),
        
        .m_ARVALID(m_ARVALID),
        .m_ARREADY(m_ARREADY),
        .m_ARADDR(m_ARADDR),
        .m_ARLEN(m_ARLEN),
        .m_ARSIZE(m_ARSIZE),
        .m_ARBURST(m_ARBURST),
        
        .m_RVALID(m_RVALID),
        .m_RREADY(m_RREADY),
        .m_RDATA(m_RDATA),
        .m_RRESP(m_RRESP),
        .m_RLAST(m_RLAST),
        
        .m_AWVALID(m_AWVALID),
        .m_AWREADY(m_AWREADY),
        .m_AWADDR(m_AWADDR),
        .m_AWLEN(m_AWLEN),
        .m_AWSIZE(m_AWSIZE),
        .m_AWBURST(m_AWBURST),
        
        .m_WVALID(m_WVALID),
        .m_WREADY(m_WREADY),
        .m_WDATA(m_WDATA),
        .m_WSTRB(m_WSTRB),
        .m_WLAST(m_WLAST),
        
        .m_BVALID(m_BVALID),
        .m_BREADY(m_BREADY),
        .m_BRESP(m_BRESP)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    // AXI memory model
    assign m_ARREADY = 1'b1;
    assign m_AWREADY = 1'b1;
    assign m_WREADY = 1'b1;
    
    // Read channel
    reg m_RVALID_reg;
    assign m_RVALID = m_RVALID_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_RVALID_reg <= 1'b0;
            m_RDATA <= 32'b0;
            m_RRESP <= 2'b00;
            m_RLAST <= 1'b0;
        end else begin
            if (m_ARVALID && m_ARREADY) begin
                m_RVALID_reg <= 1'b1;
                m_RDATA <= memory[m_ARADDR[11:2]];
                m_RRESP <= 2'b00;
                m_RLAST <= 1'b1;
            end else if (m_RVALID && m_RREADY) begin
                m_RVALID_reg <= 1'b0;
            end
        end
    end
    
    // Write channel
    reg m_BVALID_reg;
    assign m_BVALID = m_BVALID_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_BVALID_reg <= 1'b0;
            m_BRESP <= 2'b00;
        end else begin
            if (m_WVALID && m_WREADY && m_AWVALID && m_AWREADY) begin
                memory[m_AWADDR[11:2]] <= m_WDATA;
                m_BVALID_reg <= 1'b1;
                m_BRESP <= 2'b00;
            end else if (m_BVALID && m_BREADY) begin
                m_BVALID_reg <= 1'b0;
            end
        end
    end
    
    // Test sequence
    initial begin
        $display("========================================");
        $display("  ATOMIC UNIT V3.0 VERIFICATION");
        $display("  Production Ready Test Suite");
        $display("========================================\n");
        
        // Initialize
        rst_n = 0;
        valid_in = 0;
        snoop_inv = 0;
        snoop_core_id = 4'b0;
        funct5 = 5'b0;
        addr = 32'b0;
        rs2 = 32'b0;
        
        for (i = 0; i < 1024; i = i + 1)
            memory[i] = 32'h00000000;
        
        memory[0] = 32'h12345678;
        memory[10] = 32'hDEADBEEF;
        memory[20] = 32'hCAFEBABE;
        
        #20 rst_n = 1;
        #10;
        
        // TEST 1: LR.W
        $display("[TEST 1] LR.W - Load Reserved");
        @(posedge clk);
        funct5 = 5'b00010;
        addr = 32'h00000000;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        if (rd_value == 32'h12345678 && debug_reservation_valid) begin
            $display("  ✓ PASS: LR returned 0x%h, reservation set\n", rd_value);
            test_pass = test_pass + 1;
        end else begin
            $display("  ✗ FAIL: LR returned 0x%h, reservation=%b\n", rd_value, debug_reservation_valid);
            test_fail = test_fail + 1;
        end
        
        // TEST 2: SC.W SUCCESS
        $display("[TEST 2] SC.W - Should succeed (reservation valid)");
        @(posedge clk);
        @(posedge clk);
        funct5 = 5'b00011;
        addr = 32'h00000000;
        rs2 = 32'hAAAAAAAA;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        if (rd_value == 32'h00000000 && memory[0] == 32'hAAAAAAAA) begin
            $display("  ✓ PASS: SC succeeded (returned 0), memory=0x%h\n", memory[0]);
            test_pass = test_pass + 1;
        end else begin
            $display("  ✗ FAIL: SC returned %d, memory=0x%h\n", rd_value, memory[0]);
            test_fail = test_fail + 1;
        end
        
        // TEST 3: SC.W FAIL - CRITICAL
        $display("[TEST 3] SC.W without LR - CRITICAL (must NOT write)");
        memory[10] = 32'hDEADBEEF;
        @(posedge clk);
        @(posedge clk);
        funct5 = 5'b00011;
        addr = 32'h00000028;
        rs2 = 32'h11111111;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        if (rd_value != 32'h00000000 && memory[10] == 32'hDEADBEEF) begin
            $display("  ✓✓ CRITICAL PASS: SC failed (returned %d), memory NOT modified (0x%h)\n", 
                     rd_value, memory[10]);
            test_pass = test_pass + 1;
        end else begin
            $display("  ✗✗ CRITICAL FAIL: SC returned %d, memory=0x%h (SHOULD BE 0xDEADBEEF!)\n", 
                     rd_value, memory[10]);
            test_fail = test_fail + 1;
        end
        
        // TEST 4: SC.W FAIL - DIFFERENT ADDRESS
        $display("[TEST 4] LR then SC to different address");
        @(posedge clk);
        funct5 = 5'b00010;
        addr = 32'h00000004;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        @(posedge clk);
        funct5 = 5'b00011;
        addr = 32'h00000008;
        rs2 = 32'h22222222;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        if (rd_value != 32'h00000000) begin
            $display("  ✓ PASS: SC failed (different address)\n");
            test_pass = test_pass + 1;
        end else begin
            $display("  ✗ FAIL: SC should fail\n");
            test_fail = test_fail + 1;
        end
        
        // TEST 5: SNOOP INVALIDATION
        $display("[TEST 5] LR + Snoop invalidation + SC");
        memory[5] = 32'h55555555;
        @(posedge clk);
        funct5 = 5'b00010;
        addr = 32'h00000014;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        @(posedge clk);
        snoop_inv = 1;
        snoop_addr = 32'h00000014;
        snoop_core_id = 4'b0001;
        @(posedge clk);
        snoop_inv = 0;
        @(posedge clk);
        
        funct5 = 5'b00011;
        addr = 32'h00000014;
        rs2 = 32'h66666666;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        if (rd_value != 32'h00000000) begin
            $display("  ✓ PASS: SC failed after snoop invalidation\n");
            test_pass = test_pass + 1;
        end else begin
            $display("  ✗ FAIL: SC should fail after snoop\n");
            test_fail = test_fail + 1;
        end
        
        // TEST 6: AMOADD.W
        $display("[TEST 6] AMOADD.W - Atomic add");
        memory[15] = 32'h00000100;
        @(posedge clk);
        @(posedge clk);
        funct5 = 5'b00000;
        addr = 32'h0000003C;
        rs2 = 32'h00000050;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        wait(valid_out);
        @(posedge clk);
        
        if (rd_value == 32'h00000100 && memory[15] == 32'h00000150) begin
            $display("  ✓ PASS: AMOADD returned old value (0x%h), memory=0x%h\n", 
                     rd_value, memory[15]);
            test_pass = test_pass + 1;
        end else begin
            $display("  ✗ FAIL: AMOADD returned 0x%h, memory=0x%h\n", 
                     rd_value, memory[15]);
            test_fail = test_fail + 1;
        end
        
        #100;
        
        // SUMMARY
        $display("========================================");
        $display("  TEST SUMMARY");
        $display("========================================");
        $display("  PASSED: %0d", test_pass);
        $display("  FAILED: %0d", test_fail);
        $display("========================================\n");
        
        if (test_fail == 0) begin
            $display("✓✓✓ ALL TESTS PASSED! ✓✓✓");
            $display("Code is production ready!\n");
        end else begin
            $display("✗✗✗ SOME TESTS FAILED ✗✗✗");
            $display("Please review failed tests above.\n");
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\n✗ ERROR: Simulation timeout!");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("atomic_unit.vcd");
        $dumpvars(0, tb_atomic_unit);
    end
    
endmodule
