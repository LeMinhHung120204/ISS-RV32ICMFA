`timescale 1ns/1ps

module tb_lr_w;
    reg clk, rst_n, lr_en;
    reg [31:0] addr;
    wire [31:0] rd_data, mem_addr, lr_addr_out;
    wire mem_req, lr_valid, lr_done;
    
    // AXI Read Address Channel
    wire axi_arvalid;
    reg  axi_arready;
    wire [31:0] axi_araddr;
    wire [2:0]  axi_arsize;
    wire [1:0]  axi_arlock;
    
    // AXI Read Data Channel
    reg         axi_rvalid;
    wire        axi_rready;
    reg  [31:0] axi_rdata;
    wire [1:0]  axi_rresp;

    assign axi_rresp = 2'b00;

    lr_w dut (
        .clk(clk), .rst_n(rst_n), .lr_en(lr_en),
        .addr(addr), .mem_rdata(axi_rdata), .mem_ready(1'b0),
        .rd_data(rd_data), .mem_req(mem_req), .mem_addr(mem_addr),
        .lr_valid(lr_valid), .lr_addr_out(lr_addr_out), .lr_done(lr_done),
        .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
        .axi_araddr(axi_araddr), .axi_arsize(axi_arsize), .axi_arlock(axi_arlock),
        .axi_rvalid(axi_rvalid), .axi_rready(axi_rready),
        .axi_rdata(axi_rdata), .axi_rresp(axi_rresp)  //
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; lr_en = 0; addr = 0;
        axi_arready = 0; axi_rvalid = 0; axi_rdata = 0;
        
        #10 rst_n = 1;
        #10;
        // Test 1: Load value 100 at address 0x1000
        lr_en = 1; addr = 32'h1000;
        #10 lr_en = 0;
        #10 axi_arready = 1;
        #10 axi_arready = 0;
        #10 axi_rvalid = 1; axi_rdata = 32'd100;
        #10 axi_rvalid = 0;
        
        #20;
        // Test 2: Load value 200 at address 0x2000
        lr_en = 1; addr = 32'h2000;
        #10 lr_en = 0;
        #10 axi_arready = 1;
        #10 axi_arready = 0;
        #10 axi_rvalid = 1; axi_rdata = 32'd200;
        #10 axi_rvalid = 0;
        
        #20;
        // Test 3: Load negative value at address 0x3000
        lr_en = 1; addr = 32'h3000;
        #10 lr_en = 0;
        #10 axi_arready = 1;
        #10 axi_arready = 0;
        #10 axi_rvalid = 1; axi_rdata = 32'hFFFFFFEC;  // -20
        #10 axi_rvalid = 0;
        
        #50 $finish;
    end
endmodule
