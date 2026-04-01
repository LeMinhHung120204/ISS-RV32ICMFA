`timescale 1ns / 1ps

module tb_atomic_simple;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam ID_WIDTH   = 4;

    // =========================================================================
    // Signals
    // =========================================================================
    
    reg clk;
    reg rstn;

    // CPU Interface Signals
    reg  [31:0]           cpu_instr;
    reg                   cpu_instr_valid;
    wire                  cpu_instr_ready;
    reg  [ID_WIDTH-1:0]   cpu_core_id;
    reg  [ADDR_WIDTH-1:0] cpu_rs1_data;
    reg  [ADDR_WIDTH-1:0] cpu_rs2_data;
    
    wire [DATA_WIDTH-1:0] cpu_result;
    wire                  cpu_result_valid;
    reg                   cpu_result_ready;

    // AXI Bus Signals
    wire [ADDR_WIDTH-1:0] m_axi_araddr;
    wire                  m_axi_arvalid;
    reg                   m_axi_arready;
    
    reg  [DATA_WIDTH-1:0] m_axi_rdata;
    reg  [1:0]            m_axi_rresp;
    reg                   m_axi_rvalid;
    wire                  m_axi_rready;
    
    wire [ADDR_WIDTH-1:0] m_axi_awaddr;
    wire                  m_axi_awvalid;
    reg                   m_axi_awready;
    
    wire [DATA_WIDTH-1:0] m_axi_wdata;
    wire                  m_axi_wvalid;
    reg                   m_axi_wready;
    
    reg  [1:0]            m_axi_bresp;
    reg                   m_axi_bvalid;
    wire                  m_axi_bready;

    reg  [ADDR_WIDTH-1:0] snoop_addr;
    reg                   snoop_valid;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    wrapper_atomic #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .USE_LOCAL_ALU(1)
    ) dut (
        .clk(clk), 
        .rstn(rstn),
        
        .cpu_instr(cpu_instr),
        .cpu_instr_valid(cpu_instr_valid),
        .cpu_instr_ready(cpu_instr_ready),
        .cpu_core_id(cpu_core_id),
        .cpu_rs1_data(cpu_rs1_data),
        .cpu_rs2_data(cpu_rs2_data),
        
        .cpu_result(cpu_result),
        .cpu_result_valid(cpu_result_valid),
        .cpu_result_ready(cpu_result_ready),
        
        .m_axi_araddr(m_axi_araddr), 
        .m_axi_arvalid(m_axi_arvalid), 
        .m_axi_arready(m_axi_arready),
        
        .m_axi_rdata(m_axi_rdata), 
        .m_axi_rresp(m_axi_rresp), 
        .m_axi_rvalid(m_axi_rvalid), 
        .m_axi_rready(m_axi_rready),
        
        .m_axi_awaddr(m_axi_awaddr), 
        .m_axi_awvalid(m_axi_awvalid), 
        .m_axi_awready(m_axi_awready),
        
        .m_axi_wdata(m_axi_wdata), 
        .m_axi_wvalid(m_axi_wvalid), 
        .m_axi_wready(m_axi_wready),
        
        .m_axi_bresp(m_axi_bresp), 
        .m_axi_bvalid(m_axi_bvalid), 
        .m_axi_bready(m_axi_bready),
        
        .m_axi_acaddr(snoop_addr), 
        .m_axi_acsnoop(4'b0), 
        .m_axi_acvalid(snoop_valid),
        .m_axi_acready(),
        .m_axi_crready(1'b1),
        .m_axi_cdready(1'b1)
    );

    // =========================================================================
    // Memory Simulation (AXI Slave)
    // =========================================================================
    reg [31:0] memory_storage [0:1023];
    integer i;
    
    initial begin
        for(i=0; i<1024; i=i+1) memory_storage[i] = 32'd0;
        memory_storage[4]  = 32'd2;    // 0x10 -> 2 (for Add tests)
        memory_storage[5]  = 32'd5;    // 0x14 -> 5 (for Swap)
        memory_storage[6]  = 32'd4;    // 0x18 -> 4 (for And/Or)
        memory_storage[7]  = 32'd5;    // 0x1C -> 5 (for Xor)
        memory_storage[8]  = 32'd5;    // 0x20 -> 5 (for Max/Min)
        memory_storage[12] = 32'd20;   // 0x30 -> 20 (for LR/SC)
        memory_storage[16] = 32'd0;    // 0x40 -> 0 (for Snoop test)
    end

    // AXI Read Channel
    always @(posedge clk) begin
        if (!rstn) begin
            m_axi_arready <= 1'b0;
            m_axi_rvalid  <= 1'b0;
            m_axi_rdata   <= 32'b0;
            m_axi_rresp   <= 2'b00;
        end else begin
            m_axi_arready <= 1'b0;
            
            if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 1'b0;
            end
            
            if (m_axi_arvalid && !m_axi_arready && !m_axi_rvalid) begin
                m_axi_arready <= 1'b1;
                m_axi_rvalid <= 1'b1;
                m_axi_rdata  <= memory_storage[m_axi_araddr[11:2]]; 
                m_axi_rresp  <= 2'b00;
            end
        end
    end

    // AXI Write Channel
    reg write_addr_captured;
    reg write_data_captured;
    reg [ADDR_WIDTH-1:0] captured_addr;
    reg [DATA_WIDTH-1:0] captured_data;

    always @(posedge clk) begin
        if (!rstn) begin
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            m_axi_bvalid  <= 1'b0;
            m_axi_bresp   <= 2'b00;
            write_addr_captured <= 1'b0;
            write_data_captured <= 1'b0;
            captured_addr <= 32'b0;
            captured_data <= 32'b0;
        end else begin
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            
            if (m_axi_awvalid && !write_addr_captured) begin
                m_axi_awready <= 1'b1;
                captured_addr <= m_axi_awaddr;
                write_addr_captured <= 1'b1;
            end
            
            if (m_axi_wvalid && !write_data_captured) begin
                m_axi_wready <= 1'b1;
                captured_data <= m_axi_wdata;
                write_data_captured <= 1'b1;
            end
            
            if (write_addr_captured && write_data_captured && !m_axi_bvalid) begin
                memory_storage[captured_addr[11:2]] <= captured_data;
                m_axi_bvalid <= 1'b1;
                m_axi_bresp  <= 2'b01;
                write_addr_captured <= 1'b0;
                write_data_captured <= 1'b0;
            end
            
            if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Test Task
    // =========================================================================
    localparam ATOMIC_OPCODE = 7'b0101111;
    
    task send_atomic_instr;
        input [4:0] funct5;
        input [1:0] aq_rl;
        input [4:0] rs1;
        input [4:0] rs2;
        input [4:0] rd;
        begin
            cpu_instr = {funct5, aq_rl[1], aq_rl[0], rs2, rs1, 3'b010, rd, ATOMIC_OPCODE};
            cpu_instr_valid = 1;
            
            wait(cpu_instr_ready);
            @(posedge clk);
            cpu_instr_valid = 0;
            
            wait(cpu_result_valid);
            #1;
            
            cpu_result_ready = 1;
            @(posedge clk);
            cpu_result_ready = 0;
            @(posedge clk); 
            @(posedge clk); 
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        clk = 0;
        rstn = 0; 
        cpu_instr = 0;
        cpu_instr_valid = 0;
        cpu_result_ready = 0;
        cpu_core_id = 0;
        cpu_rs1_data = 0;
        cpu_rs2_data = 0;
        snoop_valid = 0;
        snoop_addr = 0;
        
        #20 rstn = 1;
        #20;

        $display("=================================================");
        $display("ATOMIC UNIT COMPREHENSIVE TEST - 11 OPERATIONS");
        $display("=================================================");

        // Test 1: Add (2 + 3 = 5)
        $display("\n[TEST 1] Test_Add_Positive (2 + 3 = 5)");
        cpu_rs1_data = 32'h10;
        cpu_rs2_data = 32'd3;
        send_atomic_instr(5'b00000, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 2 && memory_storage[4] === 5) 
            $display("  [PASS] old=2, new=5"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[4]);

        // Test 2: Add with negative (5 + (-3) = 2)
        $display("\n[TEST 2] Test_Add_Negative (5 + (-3) = 2)");
        cpu_rs1_data = 32'h10;
        cpu_rs2_data = -32'd3;  // -3
        send_atomic_instr(5'b00000, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 5 && memory_storage[4] === 2) 
            $display("  [PASS] old=5, new=2"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[4]);

        // Test 3: Swap (5 <-> 10)
        $display("\n[TEST 3] Test_Swap (5 <-> 10)");
        cpu_rs1_data = 32'h14;
        cpu_rs2_data = 32'd10;
        send_atomic_instr(5'b00001, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 5 && memory_storage[5] === 10) 
            $display("  [PASS] old=5, new=10"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[5]);

        // Test 4: And (4 & 2 = 0, binary: 100 & 010 = 000)
        $display("\n[TEST 4] Test_And (4 & 2 = 0)");
        $display("  Binary: 100 & 010 = 000");
        cpu_rs1_data = 32'h18;
        cpu_rs2_data = 32'd2;
        send_atomic_instr(5'b01100, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 4 && memory_storage[6] === 0) 
            $display("  [PASS] old=4, new=0"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[6]);

        // Test 5: Or (0 | 2 = 2, binary: 000 | 010 = 010)
        $display("\n[TEST 5] Test_Or (0 | 2 = 2)");
        $display("  Binary: 000 | 010 = 010");
        cpu_rs1_data = 32'h18;
        cpu_rs2_data = 32'd2;
        send_atomic_instr(5'b01010, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 0 && memory_storage[6] === 2) 
            $display("  [PASS] old=0, new=2"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[6]);

        // Test 6: Xor (5 ^ 6 = 3, binary: 101 ^ 110 = 011)
        $display("\n[TEST 6] Test_Xor (5 ^ 6 = 3)");
        $display("  Binary: 101 ^ 110 = 011");
        cpu_rs1_data = 32'h1C;
        cpu_rs2_data = 32'd6;
        send_atomic_instr(5'b00100, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 5 && memory_storage[7] === 3) 
            $display("  [PASS] old=5, new=3"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[7]);

        // Test 7: Max signed (5 vs 10 = 10)
        $display("\n[TEST 7] Test_Max (max(5, 10) = 10)");
        cpu_rs1_data = 32'h20;
        cpu_rs2_data = 32'd10;
        send_atomic_instr(5'b10100, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 5 && memory_storage[8] === 10) 
            $display("  [PASS] old=5, new=10"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[8]);

        // Test 8: Min signed (10 vs 5 = 5)
        $display("\n[TEST 8] Test_Min (min(10, 5) = 5)");
        cpu_rs1_data = 32'h20;
        cpu_rs2_data = 32'd5;
        send_atomic_instr(5'b10000, 2'b00, 5'd1, 5'd2, 5'd3);
        if (cpu_result === 10 && memory_storage[8] === 5) 
            $display("  [PASS] old=10, new=5"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[8]);

        // ===================================================================
        // Test_Lr: LR.W (Load-Reserved) - READ ONLY, NO WRITE!
        // ===================================================================
        $display("\n[TEST 9] Test_Lr (Load-Reserved)");
        $display("  Address: 0x30, Expected: read=20, NO memory change");
        
        cpu_rs1_data = 32'h30;
        cpu_rs2_data = 32'd0;  // LR ignores rs2
        
        // Manual instruction construction for LR
        cpu_instr = {5'b00010, 2'b00, 5'd0, 5'd1, 3'b010, 5'd3, ATOMIC_OPCODE};
        cpu_instr_valid = 1;
        $display("  LR instruction sent...");
        
        wait(cpu_instr_ready);
        @(posedge clk);
        cpu_instr_valid = 0;
        
        wait(cpu_result_valid);
        #1;
        $display("  LR result received: %d", cpu_result);
        
        cpu_result_ready = 1;
        @(posedge clk);
        cpu_result_ready = 0;
        
        if (cpu_result === 20 && memory_storage[12] === 20) 
            $display("  [PASS] read=20, mem unchanged"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[12]);
        
        @(posedge clk); 
        @(posedge clk);

        // ===================================================================
        // Test_Sc_Success: SC.W (Store-Conditional) - WRITE ONLY!
        // ===================================================================
        $display("\n[TEST 10] Test_Sc_Success (Store-Conditional)");
        $display("  Address: 0x30, Write: 6, Expected: rd=0 (success), mem=6");
        
        cpu_rs1_data = 32'h30;
        cpu_rs2_data = 32'd6;
        
        // Manual instruction construction for SC
        cpu_instr = {5'b00011, 2'b00, 5'd2, 5'd1, 3'b010, 5'd3, ATOMIC_OPCODE};
        cpu_instr_valid = 1;
        $display("  SC instruction sent...");
        
        wait(cpu_instr_ready);
        @(posedge clk);
        cpu_instr_valid = 0;
        
        wait(cpu_result_valid);
        #1;
        $display("  SC result received: %d (0=success, 1=fail)", cpu_result);
        
        cpu_result_ready = 1;
        @(posedge clk);
        cpu_result_ready = 0;
        
        if (cpu_result === 0 && memory_storage[12] === 6) 
            $display("  [PASS] SC success, rd=0, mem=6"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[12]);
        
        @(posedge clk); 
        @(posedge clk);

        // ===================================================================
        // Test_Snoop: Snoop at different address with LR/SC
        // ===================================================================
        $display("\n[TEST 11] Test_Snoop (Snoop Invalidation)");
        
        // LR at 0x40
        $display("  Step 1: LR at 0x40");
        cpu_rs1_data = 32'h40;
        cpu_rs2_data = 32'd0;
        
        cpu_instr = {5'b00010, 2'b00, 5'd0, 5'd1, 3'b010, 5'd3, ATOMIC_OPCODE};
        cpu_instr_valid = 1;
        
        wait(cpu_instr_ready);
        @(posedge clk);
        cpu_instr_valid = 0;
        
        wait(cpu_result_valid);
        #1;
        $display("  LR result: %d", cpu_result);
        
        cpu_result_ready = 1;
        @(posedge clk);
        cpu_result_ready = 0;
        @(posedge clk);
        
        // Snoop event at 0x40
        $display("  Step 2: External snoop at 0x40");
        snoop_addr = 32'h40;
        snoop_valid = 1;
        @(posedge clk);
        @(posedge clk);
        snoop_valid = 0;
        @(posedge clk);
        $display("  Snoop completed");
        
        // SC attempt at 0x40 (should fail)
        $display("  Step 3: SC at 0x40 (should FAIL)");
        cpu_rs1_data = 32'h40;
        cpu_rs2_data = 32'd1;
        
        cpu_instr = {5'b00011, 2'b00, 5'd2, 5'd1, 3'b010, 5'd3, ATOMIC_OPCODE};
        cpu_instr_valid = 1;
        
        wait(cpu_instr_ready);
        @(posedge clk);
        cpu_instr_valid = 0;
        
        wait(cpu_result_valid);
        #1;
        $display("  SC result: %d (0=success, 1=fail)", cpu_result);
        
        cpu_result_ready = 1;
        @(posedge clk);
        cpu_result_ready = 0;
        
        if (cpu_result === 1 && memory_storage[16] === 0) 
            $display("  [PASS] SC fail, rd=1, mem unchanged"); 
        else 
            $display("  [FAIL] got=%d, mem=%d", cpu_result, memory_storage[16]);

        $display("\n=================================================");
        $display("ALL TESTS COMPLETED");
        $display("=================================================");
        $finish;
    end

    always #5 clk = ~clk;

endmodule
