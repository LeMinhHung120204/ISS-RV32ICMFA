`timescale 1ns/1ps

module tb_RV32I;
    reg clk, rst_n;
    reg[10:0] count_clock;

    RV32I dut(
        .clk(clk),
        .rst_n(rst_n)  
    );

    always #5 clk = ~clk;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            count_clock <= 11'd0;
        end 
        else begin
            count_clock <= count_clock + 1'b1;
        end 
    end

    initial begin
        clk = 0;
        rst_n = 0;

    #50 rst_n = 1;

    #5000;
    end
endmodule 