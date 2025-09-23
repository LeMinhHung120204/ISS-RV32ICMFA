`timescale 1ns/1ps
module RegFile(
    input               clk,
    input               rst_n, 
    input               we,
    input       [4:0]   rs1, rs2, // read address
    input       [4:0]   rd,       // write address
    input       [31:0]  wd,       // write data
    output reg  [31:0]  rd1, rd2  // read data
);
    reg [31:0] register [31:0];
    always @(*) begin
        rd1 = (rd != 5'b0 && rd == rs1 && we) ? wd : register[rs1];
        rd2 = (rd != 5'b0 && rd == rs2 && we) ? wd : register[rs2];
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < 32; i = i + 1'b1)
                register[i] <= 32'b0;
        end else if (we && rd != 5'b00000) begin
            register[rd] <= wd; 
        end
    end 
endmodule 