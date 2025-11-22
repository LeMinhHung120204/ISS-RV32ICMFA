`timescale 1ns/1ps

module atomic_unit_tb;

    // Parameters
    parameter WIDTH_DATA = 32;
    parameter WIDTH_ADDR = 32;
    parameter CORE_ID = 0;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Pipeline Inputs
    reg E_AtomicOp;
    reg [4:0] E_atomic_funct5;
    reg E_atomic_aq;
    reg E_atomic_rl;
    reg [WIDTH_ADDR-1:0] E_addr;
    reg [WIDTH_DATA-1:0] E_RD1;
    reg [WIDTH_DATA-1:0] E_RD2;

    // Pipeline Outputs
    wire E_atomic_done;
    wire [WIDTH_DATA-1:0] E_atomic_rd;
    wire atomic_stall;

    // Snoop Interface
    reg snoop_valid;
    reg [WIDTH_ADDR-1:0] snoop_addr;
    reg [3:0] snoop_type;
    reg [3:0] snoop_core_id;

    // Debug
    wire [3:0] debug_state;
    wire debug_reservation_valid;

    // AXI Master Interface
    wire m_ARVALID;
    reg m_ARREADY;
    wire [WIDTH_ADDR-1:0] m_ARADDR;
    wire [7:0] m_ARLEN;
    wire [2:0] m_ARSIZE;
    wire [1:0] m_ARBURST;

    reg m_RVALID;
    wire m_RREADY;
    reg [WIDTH_DATA-1:0] m_RDATA;
    reg [1:0] m_RRESP;
    reg m_RLAST;

    wire m_AWVALID;
    reg m_AWREADY;
    wire [WIDTH_ADDR-1:0] m_AWADDR;
    wire [7:0] m_AWLEN;
    wire [2:0] m_AWSIZE;
    wire [1:0] m_AWBURST;

    wire m_WVALID;
    reg m_WREADY;
    wire [WIDTH_DATA-1:0] m_WDATA;
    wire [3:0] m_WSTRB;
    wire m_WLAST;

    reg m_BVALID;
    wire m_BREADY;
    reg [1:0] m_BRESP;

    // ACE Extensions
    wire [3:0] m_ARSNOOP;
    wire [1:0] m_ARDOMAIN;
    wire [1:0] m_ARBAR;
    wire [2:0] m_AWSNOOP;
    wire [1:0] m_AWDOMAIN;
    wire [1:0] m_AWBAR;

    // Instantiate DUT
    atomic_wrapper #(
        .WIDTH_DATA(WIDTH_DATA),
        .WIDTH_ADDR(WIDTH_ADDR),
        .CORE_ID(CORE_ID)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .E_AtomicOp(E_AtomicOp),
        .E_atomic_funct5(E_atomic_funct5),
        .E_atomic_aq(E_atomic_aq),
        .E_atomic_rl(E_atomic_rl),
        .E_addr(E_addr),
        .E_RD1(E_RD1),
        .E_RD2(E_RD2),
        .E_atomic_done(E_atomic_done),
        .E_atomic_rd(E_atomic_rd),
        .atomic_stall(atomic_stall),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_type(snoop_type),
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
        .m_BRESP(m_BRESP),
        .m_ARSNOOP(m_ARSNOOP),
        .m_ARDOMAIN(m_ARDOMAIN),
        .m_ARBAR(m_ARBAR),
        .m_AWSNOOP(m_AWSNOOP),
        .m_AWDOMAIN(m_AWDOMAIN),
        .m_AWBAR(m_AWBAR)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // AXI Slave Logic (Verilog-2001 compatible)
    reg [31:0] next_read_data;
    reg aw_handshake_done;
    reg w_handshake_done;

    // Read Channel Handler
    initial begin
        m_ARREADY = 0;
        m_RVALID = 0;
        m_RDATA = 0;
        m_RLAST = 0;
        m_RRESP = 0;
        forever begin
            @(posedge clk);
            if (m_ARVALID && !m_ARREADY) begin
                m_ARREADY <= 1;
                @(posedge clk);
                m_ARREADY <= 0;
                
                // Latency simulation
                repeat(2) @(posedge clk);
                
                m_RVALID <= 1;
                m_RDATA <= next_read_data;
                m_RLAST <= 1;
                
                wait(m_RREADY);
                @(posedge clk);
                m_RVALID <= 0;
                m_RLAST <= 0;
            end
        end
    end

    // Write Address Handler
    initial begin
        m_AWREADY = 0;
        aw_handshake_done = 0;
        forever begin
            @(posedge clk);
            if (m_AWVALID && !m_AWREADY) begin
                m_AWREADY <= 1;
                @(posedge clk);
                m_AWREADY <= 0;
                aw_handshake_done = 1;
            end
            
            if (m_BVALID && m_BREADY) begin
                aw_handshake_done = 0;
            end
        end
    end

    // Write Data Handler
    initial begin
        m_WREADY = 0;
        w_handshake_done = 0;
        forever begin
            @(posedge clk);
            if (m_WVALID && !m_WREADY) begin
                m_WREADY <= 1;
                @(posedge clk);
                m_WREADY <= 0;
                w_handshake_done = 1;
            end
            
            if (m_BVALID && m_BREADY) begin
                w_handshake_done = 0;
            end
        end
    end

    // Write Response Handler
    initial begin
        m_BVALID = 0;
        m_BRESP = 0;
        forever begin
            @(posedge clk);
            if (aw_handshake_done && w_handshake_done && !m_BVALID) begin
                repeat(2) @(posedge clk); // Latency
                m_BVALID <= 1;
                wait(m_BREADY);
                @(posedge clk);
                m_BVALID <= 0;
            end
        end
    end

    // Test Sequence
    initial begin
        // Initialize Inputs
        rst_n = 0;
        E_AtomicOp = 0;
        E_atomic_funct5 = 0;
        E_atomic_aq = 0;
        E_atomic_rl = 0;
        E_addr = 0;
        E_RD1 = 0;
        E_RD2 = 0;
        snoop_valid = 0;
        snoop_addr = 0;
        snoop_type = 0;
        snoop_core_id = 0;
        
        // Initialize AXI Slave
        m_ARREADY = 0;
        m_RVALID = 0;
        m_RDATA = 0;
        m_RRESP = 0;
        m_RLAST = 0;
        m_AWREADY = 0;
        m_WREADY = 0;
        m_BVALID = 0;
        m_BRESP = 0;

        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        $display("=== TEST START ===");

        // ---------------------------------------------------------
        // TEST CASE 1: LR (Load Reserved)
        // ---------------------------------------------------------
        $display("\n[TEST 1] LR.W at 0x1000");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00010; // LR.W
        E_addr = 32'h1000;
        
        // Start AXI Read Handler
        next_read_data = 32'hDEADBEEF;
        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'hDEADBEEF) 
            $display("PASS: LR returned correct data");
        else 
            $display("FAIL: LR returned %h, expected DEADBEEF", E_atomic_rd);
            
        if (debug_reservation_valid) 
            $display("PASS: Reservation set");
        else 
            $display("FAIL: Reservation NOT set");

        if (m_ARSNOOP === 4'b0001)
            $display("PASS: ARSNOOP is ReadShared (0001)");
        else
            $display("FAIL: ARSNOOP is %b", m_ARSNOOP);

        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 2: SC (Store Conditional) - Success
        // ---------------------------------------------------------
        $display("\n[TEST 2] SC.W at 0x1000 (Should Succeed)");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00011; // SC.W
        E_addr = 32'h1000;
        E_RD2 = 32'hCAFEBABE; // Data to write
        
        // Start AXI Write Handler (SC does Read then Write? No, SC just checks reservation then writes)
        // Wait, the state machine does R_WAIT even for SC?
        // Let's check atomic_unit_ace.v:
        // IDLE -> AR_WAIT -> R_WAIT -> CHECK_SC
        // So SC DOES perform a read first!
        // This is actually inefficient for SC if we already have the line, but maybe required if we don't.
        // If we have reservation, we might not need to read?
        // But the current implementation DOES read.
        // So we need to handle the read first.
        
        next_read_data = 32'hDEADBEEF; // Read phase of SC
        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h0) 
            $display("PASS: SC returned 0 (Success)");
        else 
            $display("FAIL: SC returned %h (Fail)", E_atomic_rd);
            
        if (!debug_reservation_valid) 
            $display("PASS: Reservation cleared after SC");
        else 
            $display("FAIL: Reservation NOT cleared after SC");

        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 3: LR -> Snoop -> SC (Fail)
        // ---------------------------------------------------------
        $display("\n[TEST 3] LR -> Snoop -> SC (Should Fail)");
        
        // 3a. Perform LR
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00010; // LR.W
        E_addr = 32'h2000;
        
        next_read_data = 32'h12345678;
        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (debug_reservation_valid) $display("PASS: LR Reservation set");
        
        repeat(2) @(posedge clk);
        
        // 3b. Inject Snoop (ReadUnique = 0111) from Core 1
        $display("Injecting Snoop ReadUnique...");
        snoop_valid = 1;
        snoop_addr = 32'h2000;
        snoop_type = 4'b0111; // ReadUnique
        snoop_core_id = 4'h1; // Different core
        @(posedge clk);
        snoop_valid = 0;
        @(posedge clk);
        
        if (!debug_reservation_valid) 
            $display("PASS: Reservation invalidated by Snoop");
        else 
            $display("FAIL: Reservation NOT invalidated by Snoop");
            
        // 3c. Perform SC
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00011; // SC.W
        E_addr = 32'h2000;
        E_RD2 = 32'hBADF00D;
        
        // SC still reads first in this implementation
        next_read_data = 32'h12345678;
        
        // But it should NOT write
        // We can check if AWVALID goes high. 
        // The TB axi_write_response might hang if AWVALID never comes.
        // So we won't call axi_write_response.
        
        @(posedge clk);
        while (!E_atomic_done) begin
            if (m_AWVALID) begin
                $display("FAIL: SC tried to write despite invalid reservation!");
                // Handshake to finish
                m_AWREADY = 1; @(posedge clk); m_AWREADY = 0;
                m_WREADY = 1; @(posedge clk); m_WREADY = 0;
                repeat(2) @(posedge clk);
                m_BVALID = 1; @(posedge clk); m_BVALID = 0;
            end
            @(posedge clk);
        end
        
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h1) 
            $display("PASS: SC returned 1 (Fail)");
        else 
            $display("FAIL: SC returned %h (Success?)", E_atomic_rd);

        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 4: AMOADD
        // ---------------------------------------------------------
        $display("\n[TEST 4] AMOADD at 0x3000");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00000; // AMOADD
        E_addr = 32'h3000;
        E_RD2 = 32'h10; // Add 0x10
        
        // Read phase
        next_read_data = 32'h20; // Memory has 0x20
        
        // Write phase

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h20) 
            $display("PASS: AMOADD returned old value 0x20");
        else 
            $display("FAIL: AMOADD returned %h, expected 0x20", E_atomic_rd);
            
        if (m_ARSNOOP === 4'b0111)
            $display("PASS: AMO ARSNOOP is ReadUnique (0111)");
        else
            $display("FAIL: AMO ARSNOOP is %b", m_ARSNOOP);

        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 5: AMOSWAP
        // ---------------------------------------------------------
        $display("\n[TEST 5] AMOSWAP at 0x3004");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00001; // AMOSWAP
        E_addr = 32'h3004;
        E_RD2 = 32'hAABBCCDD; // New value
        
        next_read_data = 32'h11223344; // Old value

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h11223344) $display("PASS: AMOSWAP returned old value");
        else $display("FAIL: AMOSWAP returned %h", E_atomic_rd);
        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 6: AMOXOR
        // ---------------------------------------------------------
        $display("\n[TEST 6] AMOXOR at 0x3008");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00100; // AMOXOR
        E_addr = 32'h3008;
        E_RD2 = 32'h0000FFFF; 
        
        next_read_data = 32'hFFFF0000; // Old value

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'hFFFF0000) $display("PASS: AMOXOR returned old value");
        else $display("FAIL: AMOXOR returned %h", E_atomic_rd);
        // Expected write: FFFF0000 ^ 0000FFFF = FFFFFFFF
        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 7: AMOAND
        // ---------------------------------------------------------
        $display("\n[TEST 7] AMOAND at 0x300C");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b01100; // AMOAND
        E_addr = 32'h300C;
        E_RD2 = 32'h0000FFFF; 
        
        next_read_data = 32'hFFFF0000; // Old value

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'hFFFF0000) $display("PASS: AMOAND returned old value");
        else $display("FAIL: AMOAND returned %h", E_atomic_rd);
        // Expected write: FFFF0000 & 0000FFFF = 00000000
        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 8: AMOOR
        // ---------------------------------------------------------
        $display("\n[TEST 8] AMOOR at 0x3010");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b01000; // AMOOR
        E_addr = 32'h3010;
        E_RD2 = 32'h0000FFFF; 
        
        next_read_data = 32'hFFFF0000; // Old value

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'hFFFF0000) $display("PASS: AMOOR returned old value");
        else $display("FAIL: AMOOR returned %h", E_atomic_rd);
        // Expected write: FFFF0000 | 0000FFFF = FFFFFFFF
        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 9: AMOMIN (Signed)
        // ---------------------------------------------------------
        $display("\n[TEST 9] AMOMIN (Signed) at 0x3014");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b10000; // AMOMIN
        E_addr = 32'h3014;
        E_RD2 = 32'hFFFFFFFE; // -2
        
        next_read_data = 32'h00000001; // 1 (Old value)

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h00000001) $display("PASS: AMOMIN returned old value");
        else $display("FAIL: AMOMIN returned %h", E_atomic_rd);
        // Expected write: min(1, -2) = -2 (FFFFFFFE)
        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 10: AMOMAX (Signed)
        // ---------------------------------------------------------
        $display("\n[TEST 10] AMOMAX (Signed) at 0x3018");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b10100; // AMOMAX
        E_addr = 32'h3018;
        E_RD2 = 32'hFFFFFFFE; // -2
        
        next_read_data = 32'h00000001; // 1 (Old value)

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h00000001) $display("PASS: AMOMAX returned old value");
        else $display("FAIL: AMOMAX returned %h", E_atomic_rd);
        // Expected write: max(1, -2) = 1 (00000001)
        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 11: AMOMINU (Unsigned)
        // ---------------------------------------------------------
        $display("\n[TEST 11] AMOMINU (Unsigned) at 0x301C");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b11000; // AMOMINU
        E_addr = 32'h301C;
        E_RD2 = 32'hFFFFFFFE; // Large unsigned number
        
        next_read_data = 32'h00000001; // 1 (Old value)

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h00000001) $display("PASS: AMOMINU returned old value");
        else $display("FAIL: AMOMINU returned %h", E_atomic_rd);
        // Expected write: minu(1, FFFFFFFE) = 1 (00000001)
        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 12: AMOMAXU (Unsigned)
        // ---------------------------------------------------------
        $display("\n[TEST 12] AMOMAXU (Unsigned) at 0x3020");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b11100; // AMOMAXU
        E_addr = 32'h3020;
        E_RD2 = 32'hFFFFFFFE; // Large unsigned number
        
        next_read_data = 32'h00000001; // 1 (Old value)

        
        @(posedge clk);
        while (!E_atomic_done) @(posedge clk);
        E_AtomicOp = 0;
        
        if (E_atomic_rd === 32'h00000001) $display("PASS: AMOMAXU returned old value");
        else $display("FAIL: AMOMAXU returned %h", E_atomic_rd);
        // Expected write: maxu(1, FFFFFFFE) = FFFFFFFE
        repeat(5) @(posedge clk);

        $display("\n=== TEST COMPLETE ===");
        $finish;
    end

endmodule
