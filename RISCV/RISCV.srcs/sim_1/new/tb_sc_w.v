`timescale 1ns/1ps

module tb_sc_w;
    reg clk, rst_n, sc_en, rsv_valid;
    reg [31:0] addr, wdata, rsv_addr;
    wire [31:0] rd_data, mem_addr, mem_wdata;
    wire mem_req, mem_we, sc_done;
    
    // AXI Write Address Channel
    wire axi_awvalid;
    reg  axi_awready;
    wire [31:0] axi_awaddr;
    wire [2:0]  axi_awsize;
    wire [1:0]  axi_awlock;
    
    // AXI Write Data Channel
    wire axi_wvalid;
    reg  axi_wready;
    wire [31:0] axi_wdata;
    wire [3:0]  axi_wstrb;
    
    // AXI Write Response Channel
    reg         axi_bvalid;
    wire        axi_bready;
    reg  [1:0]  axi_bresp;

    sc_w dut (
        .clk(clk), .rst_n(rst_n), .sc_en(sc_en),
        .addr(addr), .wdata(wdata), .rsv_valid(rsv_valid), .rsv_addr(rsv_addr),
        .mem_ready(1'b0), .rd_data(rd_data),
        .mem_req(mem_req), .mem_addr(mem_addr), .mem_we(mem_we),
        .mem_wdata(mem_wdata), .sc_done(sc_done),
        .axi_awvalid(axi_awvalid), .axi_awready(axi_awready),
        .axi_awaddr(axi_awaddr), .axi_awsize(axi_awsize), .axi_awlock(axi_awlock),
        .axi_wvalid(axi_wvalid), .axi_wready(axi_wready),
        .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb),
        .axi_bvalid(axi_bvalid), .axi_bready(axi_bready), .axi_bresp(axi_bresp)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; sc_en = 0; rsv_valid = 0;
        addr = 0; wdata = 0; rsv_addr = 0;
        axi_awready = 0; axi_wready = 0; axi_bvalid = 0; axi_bresp = 0;
        #10 rst_n = 1;
        #10;
        // Test 1: SC success (rsv match) - write 100 at 0x1000
        rsv_valid = 1; rsv_addr = 32'h1000;
        sc_en = 1; addr = 32'h1000; wdata = 32'd100;
        #10 sc_en = 0;
        #10 axi_awready = 1; axi_wready = 1;
        #10 axi_awready = 0; axi_wready = 0;
        #10 axi_bvalid = 1; axi_bresp = 2'b00;
        #10 axi_bvalid = 0; axi_bresp = 2'bxx;  // Reset
        #20;
        // Test 2: SC fail (rsv mismatch)
        rsv_valid = 1; rsv_addr = 32'h1000;
        sc_en = 1; addr = 32'h2000; wdata = 32'd200;
        #10 sc_en = 0;
        #30;
        // Test 3: SC success - write -50 at 0x3000
        rsv_valid = 1; rsv_addr = 32'h3000;
        sc_en = 1; addr = 32'h3000; wdata = 32'hFFFFFFCE;
        #10 sc_en = 0;
        #10 axi_awready = 1; axi_wready = 1;
        #10 axi_awready = 0; axi_wready = 0;
        #10 axi_bvalid = 1; axi_bresp = 2'b00;
        #10 axi_bvalid = 0; axi_bresp = 2'bxx;
        #50 $finish;
    end
endmodule
