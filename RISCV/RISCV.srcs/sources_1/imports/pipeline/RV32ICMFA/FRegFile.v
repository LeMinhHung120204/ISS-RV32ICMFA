`timescale 1ns/1ps
module FRegFile(
    input               clk,
    input               rst_n, 
    input               we,
    input       [4:0]   rs1, rs2, rs3,
    input       [4:0]   rd,       // write address
    input       [31:0]  wd,       // write data
    output reg  [31:0]  rd1, rd2, rd3
);
    reg [31:0] freg [31:0];
    always @(*) begin
        rd1 = (rd == rs1 && we) ? wd : freg[rs1];
        rd2 = (rd == rs2 && we) ? wd : freg[rs2];
        rd3 = (rd == rs3 && we) ? wd : freg[rs3];
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < 32; i = i + 1'b1)
                freg[i] <= 32'b0;
        end else if (we) begin
            freg[rd] <= wd; 
        end
    end 
endmodule 