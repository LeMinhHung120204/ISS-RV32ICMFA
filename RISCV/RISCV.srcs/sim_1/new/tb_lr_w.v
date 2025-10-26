`timescale 1ns/1ps

module tb_lr_w;
    reg clk, rst_n, lr_en, mem_ready;
    reg [31:0] addr, mem_rdata;
    wire [31:0] rd_data, mem_addr, lr_addr_out;
    wire mem_req, lr_valid, lr_done;

    lr_w dut (
        .clk(clk), .rst_n(rst_n), .lr_en(lr_en),
        .addr(addr), .mem_rdata(mem_rdata), .mem_ready(mem_ready),
        .rd_data(rd_data), .mem_req(mem_req), .mem_addr(mem_addr),
        .lr_valid(lr_valid), .lr_addr_out(lr_addr_out), .lr_done(lr_done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        clk = 1'b0; rst_n = 1'b0; lr_en = 1'b0; mem_ready = 1'b0;
        addr = 32'h0; mem_rdata = 32'h0;

        #10 rst_n = 1'b1;

        #10;
        // Load 0
        lr_en = 1'b1; addr = 32'h1000;
        #10 lr_en = 1'b0;
        #20 mem_ready = 1'b1; mem_rdata = 32'd0;
        #10 mem_ready = 1'b0;

        #20;
        // Load 12
        lr_en = 1'b1; addr = 32'h2000;
        #10 lr_en = 1'b0;
        #20 mem_ready = 1'b1; mem_rdata = 32'd12;
        #10 mem_ready = 1'b0;

        #20;
        // Load -20
        lr_en = 1'b1; addr = 32'h3000;
        #10 lr_en = 1'b0;
        #20 mem_ready = 1'b1; mem_rdata = -32'd20;
        #10 mem_ready = 1'b0;

        #30 $finish;
    end
endmodule
