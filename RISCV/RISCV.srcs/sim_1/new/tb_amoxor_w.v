`timescale 1ns/1ps

module tb_amoxor_w;
    reg clk, rst_n, valid_input;
    reg [31:0] rs1, rs2, mem_rdata;
    wire valid_output;
    wire [31:0] rd, mem_addr, mem_wdata;

    amoxor_w dut (
        .clk(clk), .rst_n(rst_n), .valid_input(valid_input),
        .rs1(rs1), .rs2(rs2), .mem_rdata(mem_rdata),
        .valid_output(valid_output), .rd(rd),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; valid_input = 0; rs1 = 0; rs2 = 0; mem_rdata = 0;
        #10 rst_n = 1;

        #10;
        // Test 1: 2 ^ 5 = 7
        valid_input = 1; rs1 = 32'h1000; rs2 = 32'd2; mem_rdata = 32'd5;
        #10;
        // Test 2: 10 ^ 15 = 5
        valid_input = 1; rs1 = 32'h2000; rs2 = 32'd10; mem_rdata = 32'd15;
        #10;
        // Test 3: 15 ^ 20 = 27
        valid_input = 1; rs1 = 32'h3000; rs2 = 32'd15; mem_rdata = 32'd20;
        #10;
        valid_input = 0;

        #50 $finish;
    end
endmodule
