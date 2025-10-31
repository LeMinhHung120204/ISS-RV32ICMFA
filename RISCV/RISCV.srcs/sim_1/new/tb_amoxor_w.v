`timescale 1ns/1ps

module tb_amoxor_w;
    reg clk, rst_n, valid_input;
    reg [31:0] rs1, rs2;
    wire valid_output;
    wire [31:0] rd, mem_addr, mem_wdata;
    wire axi_arvalid, axi_rready, axi_awvalid, axi_wvalid, axi_bready;
    reg  axi_arready, axi_rvalid, axi_awready, axi_wready, axi_bvalid;
    wire [31:0] axi_araddr, axi_awaddr, axi_wdata;
    wire [2:0]  axi_arsize, axi_awsize;
    wire [1:0]  axi_arlock, axi_awlock;
    wire [3:0]  axi_wstrb;
    reg  [31:0] axi_rdata;

    amoxor_w dut (
        .clk(clk), .rst_n(rst_n), .valid_input(valid_input),
        .rs1(rs1), .rs2(rs2), .mem_rdata(32'h0),
        .valid_output(valid_output), .rd(rd), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .axi_arvalid(axi_arvalid), .axi_arready(axi_arready), .axi_araddr(axi_araddr),
        .axi_arsize(axi_arsize), .axi_arlock(axi_arlock),
        .axi_rvalid(axi_rvalid), .axi_rready(axi_rready), .axi_rdata(axi_rdata), .axi_rresp(),
        .axi_awvalid(axi_awvalid), .axi_awready(axi_awready), .axi_awaddr(axi_awaddr),
        .axi_awsize(axi_awsize), .axi_awlock(axi_awlock),
        .axi_wvalid(axi_wvalid), .axi_wready(axi_wready), .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb),
        .axi_bvalid(axi_bvalid), .axi_bready(axi_bready), .axi_bresp()
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; valid_input = 0; rs1 = 0; rs2 = 0;
        axi_arready = 0; axi_rvalid = 0; axi_rdata = 0;
        axi_awready = 0; axi_wready = 0; axi_bvalid = 0;
        #10 rst_n = 1;
        #10;
        // Test 1: 0xF0 XOR 0x0F = 0xFF
        valid_input = 1; rs1 = 32'h1000; rs2 = 32'h0F;
        #10 valid_input = 0;
        #10 axi_arready = 1;
        #10 axi_arready = 0;
        #10 axi_rvalid = 1; axi_rdata = 32'hF0;  // mem = 0xF0
        #10 axi_rvalid = 0;
        #10 axi_awready = 1; axi_wready = 1;
        #10 axi_awready = 0; axi_wready = 0;
        #10 axi_bvalid = 1;
        #10 axi_bvalid = 0;
        #30;
        // Test 2: 0x12 XOR 0x34 = 0x26
        valid_input = 1; rs1 = 32'h2000; rs2 = 32'h34;
        #10 valid_input = 0;
        #10 axi_arready = 1;
        #10 axi_arready = 0;
        #10 axi_rvalid = 1; axi_rdata = 32'h12;  // mem = 0x12
        #10 axi_rvalid = 0;
        #10 axi_awready = 1; axi_wready = 1;
        #10 axi_awready = 0; axi_wready = 0;
        #10 axi_bvalid = 1;
        #10 axi_bvalid = 0;
        #50 $finish;
    end
endmodule
