`timescale 1ns/1ps

module atomic_wrapper_tb;

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

    // Watchdog for simulation hang
    initial begin
        #10000;
        $display("ERROR: Simulation Timeout!");
        $finish;
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

        $display("=== WRAPPER TEST START ===");

        // ---------------------------------------------------------
        // TEST CASE 1: LR (Load Reserved)
        // ---------------------------------------------------------
        $display("\n[TEST 1] LR.W at 0x1000");
        E_AtomicOp = 1;
        E_atomic_funct5 = 5'b00010; // LR.W
        E_addr = 32'h1000;
        
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

        repeat(5) @(posedge clk);

        // ---------------------------------------------------------
        // TEST CASE 2: Snoop Invalidation Logic
        // ---------------------------------------------------------
        $display("\n[TEST 2] Snoop Invalidation");
        
        // Inject Snoop (ReadUnique = 0111) from Core 1
        $display("Injecting Snoop ReadUnique...");
        snoop_valid = 1;
        snoop_addr = 32'h1000;
        snoop_type = 4'b0111; // ReadUnique
        snoop_core_id = 4'h1; // Different core
        @(posedge clk);
        snoop_valid = 0;
        @(posedge clk);
        
        // Wait for register update in wrapper
        repeat(2) @(posedge clk);
        
        if (!debug_reservation_valid) 
            $display("PASS: Reservation invalidated by Snoop");
        else 
            $display("FAIL: Reservation NOT invalidated by Snoop");

        $display("\n=== WRAPPER TEST COMPLETE ===");
        $finish;
    end

endmodule
