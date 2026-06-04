`timescale 1ns/1ps
`include "define.vh"

module tb_vc707_soc;

    // Clock and Reset
    reg ACLK;
    reg ARESETn;
    reg core_reset;

    // AXI4-Lite Slave Interface for INIT RAM
    reg  [31:0] s01_axi_awaddr;
    reg         s01_axi_awvalid;
    wire        s01_axi_awready;
    reg  [31:0] s01_axi_wdata;
    reg  [3:0]  s01_axi_wstrb;
    reg         s01_axi_wvalid;
    wire        s01_axi_wready;
    wire [1:0]  s01_axi_bresp;
    wire        s01_axi_bvalid;
    reg         s01_axi_bready;
    reg  [31:0] s01_axi_araddr;
    reg         s01_axi_arvalid;
    wire        s01_axi_arready;
    wire [31:0] s01_axi_rdata;
    wire [1:0]  s01_axi_rresp;
    wire        s01_axi_rvalid;
    reg         s01_axi_rready;

    // AXI4-Lite SLAVE INTERFACE (Dummy connection)
    reg  [3:0]  s00_axi_awaddr  = 0;
    reg  [2:0]  s00_axi_awprot  = 0;
    reg         s00_axi_awvalid = 0;
    wire        s00_axi_awready;
    reg  [31:0] s00_axi_wdata   = 0;
    reg  [3:0]  s00_axi_wstrb   = 0;
    reg         s00_axi_wvalid  = 0;
    wire        s00_axi_wready;
    wire [1:0]  s00_axi_bresp;
    wire        s00_axi_bvalid;
    reg         s00_axi_bready  = 0;
    reg  [3:0]  s00_axi_araddr  = 0;
    reg  [2:0]  s00_axi_arprot  = 0;
    reg         s00_axi_arvalid = 0;
    wire        s00_axi_arready;
    wire [31:0] s00_axi_rdata;
    wire [1:0]  s00_axi_rresp;
    wire        s00_axi_rvalid;
    reg         s00_axi_rready  = 0;

    // Instantiate the DUT
    vc707_soc dut (
        .ACLK               (ACLK),
        .ARESETn            (ARESETn),
        .core_reset         (core_reset),

        // AXI4-Lite INIT RAM
        .s01_axi_awaddr     (s01_axi_awaddr),
        .s01_axi_awvalid    (s01_axi_awvalid),
        .s01_axi_awready    (s01_axi_awready),
        .s01_axi_wdata      (s01_axi_wdata),
        .s01_axi_wstrb      (s01_axi_wstrb),
        .s01_axi_wvalid     (s01_axi_wvalid),
        .s01_axi_wready     (s01_axi_wready),
        .s01_axi_bresp      (s01_axi_bresp),
        .s01_axi_bvalid     (s01_axi_bvalid),
        .s01_axi_bready     (s01_axi_bready),
        .s01_axi_araddr     (s01_axi_araddr),
        .s01_axi_arvalid    (s01_axi_arvalid),
        .s01_axi_arready    (s01_axi_arready),
        .s01_axi_rdata      (s01_axi_rdata),
        .s01_axi_rresp      (s01_axi_rresp),
        .s01_axi_rvalid     (s01_axi_rvalid),
        .s01_axi_rready     (s01_axi_rready),

        // AXI4-Lite SLAVE
        .s00_axi_awaddr     (s00_axi_awaddr),
        .s00_axi_awprot     (s00_axi_awprot),
        .s00_axi_awvalid    (s00_axi_awvalid),
        .s00_axi_awready    (s00_axi_awready),
        .s00_axi_wdata      (s00_axi_wdata),
        .s00_axi_wstrb      (s00_axi_wstrb),
        .s00_axi_wvalid     (s00_axi_wvalid),
        .s00_axi_wready     (s00_axi_wready),
        .s00_axi_bresp      (s00_axi_bresp),
        .s00_axi_bvalid     (s00_axi_bvalid),
        .s00_axi_bready     (s00_axi_bready),
        .s00_axi_araddr     (s00_axi_araddr),
        .s00_axi_arprot     (s00_axi_arprot),
        .s00_axi_arvalid    (s00_axi_arvalid),
        .s00_axi_arready    (s00_axi_arready),
        .s00_axi_rdata      (s00_axi_rdata),
        .s00_axi_rresp      (s00_axi_rresp),
        .s00_axi_rvalid     (s00_axi_rvalid),
        .s00_axi_rready     (s00_axi_rready)
    );

    // Clock generation
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    integer log_file;
    initial begin
        log_file = $fopen("C:/Hung/Khoa_Luan/ISS-RV32ICMFA/Verilog/tb_registers.log", "w");
        if (log_file == 0) begin
            $display("ERROR: Cannot open log file!");
        end
    end

    // AXI4-Lite Write Task for s01 (RAM)
    task axi_lite_write(input [31:0] addr, input [31:0] data);
        reg aw_done, w_done;
        begin
            aw_done = 0;
            w_done = 0;
            @(posedge ACLK);
            s01_axi_awaddr  <= addr;
            s01_axi_awvalid <= 1'b1;
            s01_axi_wdata   <= data;
            s01_axi_wstrb   <= 4'b1111;
            s01_axi_wvalid  <= 1'b1;
            s01_axi_bready  <= 1'b1;

            while (!(aw_done && w_done)) begin
                @(posedge ACLK);
                if (s01_axi_awready && s01_axi_awvalid) begin
                    s01_axi_awvalid <= 1'b0;
                    aw_done = 1'b1;
                end
                if (s01_axi_wready && s01_axi_wvalid) begin
                    s01_axi_wvalid <= 1'b0;
                    w_done = 1'b1;
                end
            end

            while (!s01_axi_bvalid) begin
                @(posedge ACLK);
            end
            s01_axi_bready <= 1'b0;
        end
    endtask

    // AXI4-Lite Write Task for s00 (Registers)
    task axi_lite_write_s00(input [3:0] addr, input [31:0] data);
        reg aw_done, w_done;
        begin
            aw_done = 0;
            w_done = 0;
            @(posedge ACLK);
            s00_axi_awaddr  <= addr;
            s00_axi_awvalid <= 1'b1;
            s00_axi_wdata   <= data;
            s00_axi_wstrb   <= 4'b1111;
            s00_axi_wvalid  <= 1'b1;
            s00_axi_bready  <= 1'b1;

            while (!(aw_done && w_done)) begin
                @(posedge ACLK);
                if (s00_axi_awready && s00_axi_awvalid) begin
                    s00_axi_awvalid <= 1'b0;
                    aw_done = 1'b1;
                end
                if (s00_axi_wready && s00_axi_wvalid) begin
                    s00_axi_wvalid <= 1'b0;
                    w_done = 1'b1;
                end
            end

            while (!s00_axi_bvalid) begin
                @(posedge ACLK);
            end
            s00_axi_bready <= 1'b0;
        end
    endtask

    // AXI4-Lite Read Task for s00 (Registers)
    task axi_lite_read_s00(input [3:0] addr, output [31:0] data);
        begin
            @(posedge ACLK);
            s00_axi_araddr  <= addr;
            s00_axi_arvalid <= 1'b1;
            s00_axi_rready  <= 1'b1;
            
            while (!s00_axi_arready) begin
                @(posedge ACLK);
            end
            s00_axi_arvalid <= 1'b0;
            
            while (!s00_axi_rvalid) begin
                @(posedge ACLK);
            end
            data = s00_axi_rdata;
            s00_axi_rready <= 1'b0;
        end
    endtask

    // Task to log all registers
    task log_registers;
        input [80*8:1] test_name;
        integer core, i;
        reg [31:0] rdata;
        begin
            $fdisplay(log_file, "=======================================");
            $fdisplay(log_file, "REGISTER LOG: %0s", test_name);
            $fdisplay(log_file, "=======================================");
            
            for (core = 0; core < 2; core = core + 1) begin
                $fdisplay(log_file, "--- CORE %0d ---", core);
                for (i = 0; i < 32; i = i + 1) begin
                    axi_lite_write_s00(4'h0, (core << 5) | i);
                    axi_lite_write_s00(4'h4, 32'h1);
                    axi_lite_read_s00(4'h8, rdata);
                    axi_lite_write_s00(4'h4, 32'h0);
                    $fdisplay(log_file, "x%02d: 0x%08x", i, rdata);
                end
            end
            $fdisplay(log_file, "");
        end
    endtask

    // Main Test Sequence
    integer mem_idx;
    initial begin
        // Initialize AXI signals
        s01_axi_awaddr  = 0;
        s01_axi_awvalid = 0;
        s01_axi_wdata   = 0;
        s01_axi_wstrb   = 0;
        s01_axi_wvalid  = 0;
        s01_axi_bready  = 0;
        s01_axi_araddr  = 0;
        s01_axi_arvalid = 0;
        s01_axi_rready  = 0;

        // Reset system and keep core in reset
        ARESETn = 0;
        core_reset = 0;
        #50;
        ARESETn = 1; // Release system reset so AXI logic works
        #20;

        $display("---------------------------------------------------------");
        $display("[Init] Zeroing out the first 1024 bytes of RAM...");
        for (mem_idx = 0; mem_idx < 256; mem_idx = mem_idx + 1) begin
            axi_lite_write(mem_idx * 4, 32'h0000_0000);
        end

        $display("---------------------------------------------------------");
        $display("[Test 1] Writing Instructions while core_reset = 0 ...");
        
        // Write Test 1 for Core A (CODE_A_START = 0x0000_0000)
        /*
        addi x1, x0, 1
        addi x2, x1, 2
        add x3, x1, x2
        done:
        j done
        */
        axi_lite_write(`CODE_A_START + 0,  32'h00100093);
        axi_lite_write(`CODE_A_START + 4,  32'h00208113);
        axi_lite_write(`CODE_A_START + 8,  32'h002081b3);
        axi_lite_write(`CODE_A_START + 12, 32'h0000006f);

        // Write Test 1 for Core B (CODE_B_START = 0x0000_0100)
        /*
        addi x4, x0, 4
        addi x5, x4, 5
        add x6, x4, x5
        done:
        j done
        */
        axi_lite_write(`CODE_B_START + 0,  32'h00400213);
        axi_lite_write(`CODE_B_START + 4,  32'h00520293);
        axi_lite_write(`CODE_B_START + 8,  32'h00520333);
        axi_lite_write(`CODE_B_START + 12, 32'h0000006f);

        $display("[Test 1] Write Complete. Releasing core_reset to let cores run.");
        @(negedge ACLK);
        core_reset = 1;

        // Let cores run for a while
        #500;
        $display("[Test 1] Done. Logging registers...");
        log_registers("Test 1");

        $display("---------------------------------------------------------");
        $display("[Test 2] Asserting core_reset = 0 and loading new test...");
        core_reset = 0;
        #50;

        // Write Test 2 for Core A
        /*
        lui x1, 1
        addi x1, x1, 1
        done:
        j done
        */
        axi_lite_write(`CODE_A_START + 0,  32'h000010b7);
        axi_lite_write(`CODE_A_START + 4,  32'h00108093);
        axi_lite_write(`CODE_A_START + 8,  32'h0000006f);

        // Write Test 2 for Core B
        /*
        lui x2, 2
        addi x2, x2, 2
        done:
        j done
        */
        axi_lite_write(`CODE_B_START + 0,  32'h00002137);
        axi_lite_write(`CODE_B_START + 4,  32'h00210113);
        axi_lite_write(`CODE_B_START + 8,  32'h0000006f);

        $display("[Test 2] Write Complete. Releasing core_reset to let cores run.");
        @(negedge ACLK);
        core_reset = 1;

        // Let cores run for a while
        #500;
        $display("[Test 2] Done. Logging registers...");
        log_registers("Test 2");
        $display("---------------------------------------------------------");
        
        $fclose(log_file);
        $finish;
    end

    // Monitor register writes
    always @(posedge ACLK) begin
        if (core_reset) begin
            // We can optionally monitor the register writes directly if we want
            // For now, we will just print basic info
        end
    end

endmodule
