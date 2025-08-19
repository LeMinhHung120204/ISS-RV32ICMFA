`timescale 1ns/1ps

module tb_RV32I;
    reg clk, rst_n;
    reg[31:0] r0, r1, r2, r3, r4, r5, r6, r7, r8;

    datapath dut(
        .clk(clk),
        .rst_n(rst_n)  
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        r0 = dut.register_file.register[0];
        r1 = dut.register_file.register[1];
        r2 = dut.register_file.register[2];
        r3 = dut.register_file.register[3];
        r4 = dut.register_file.register[4];
        r5 = dut.register_file.register[5];
        r6 = dut.register_file.register[6];
        r7 = dut.register_file.register[7];
        r8 = dut.register_file.register[8];
    end

    initial begin
        clk = 0;
        rst_n = 0;

    #50 rst_n = 1;

    #10000;
    end
endmodule 