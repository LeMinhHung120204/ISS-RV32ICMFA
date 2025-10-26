`timescale 1ns/1ps

module tb_sc_w;
    reg clk, rst_n, sc_en, rsv_valid, mem_ready;
    reg [31:0] addr, wdata, rsv_addr;
    wire [31:0] rd_data, mem_addr, mem_wdata;
    wire mem_req, mem_we, sc_done;

    sc_w dut (
        .clk(clk), .rst_n(rst_n), .sc_en(sc_en),
        .addr(addr), .wdata(wdata),
        .rsv_valid(rsv_valid), .rsv_addr(rsv_addr),
        .mem_ready(mem_ready), .rd_data(rd_data),
        .mem_req(mem_req), .mem_addr(mem_addr),
        .mem_we(mem_we), .mem_wdata(mem_wdata), .sc_done(sc_done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        clk = 1'b0; rst_n = 1'b0; sc_en = 1'b0; mem_ready = 1'b0;
        rsv_valid = 1'b0; addr = 32'h0; wdata = 32'h0; rsv_addr = 32'h0;

        #10 rst_n = 1'b1;

        #10;
        // Store success 100 at 0x1000
        rsv_valid = 1'b1; rsv_addr = 32'h1000;
        sc_en = 1'b1; addr = 32'h1000; wdata = 32'd100;
        #10 sc_en = 1'b0;
        #30 mem_ready = 1'b1;
        #10 mem_ready = 1'b0;

        #20;
        // Store fail
        sc_en = 1'b1; addr = 32'h2000; wdata = 32'd200;
        #10 sc_en = 1'b0;

        #30;
        // Store -50 at 0x3000
        rsv_valid = 1'b1; rsv_addr = 32'h3000;
        sc_en = 1'b1; addr = 32'h3000; wdata = -32'd50;
        #10 sc_en = 1'b0;
        #30 mem_ready = 1'b1;
        #10 mem_ready = 1'b0;

        #30 $finish;
    end
endmodule
