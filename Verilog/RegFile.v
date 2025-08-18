`timescale 1ns/1ps

module RegFile(
    input clk,
    input rst_n, 
    input we,
    input [4:0] rs1, rs2, // read address
    input [4:0] rd,       // write address
    input [31:0] wd,            // write data
    output reg [31:0] rd1, rd2 // read data
);
    reg [31:0] register [31:0];
    always @(*) begin
        rd1 = (rd != 5'b0 && rd == rs1 && we) ? wd : register[rs1];
        rd2 = (rd != 5'b0 && rd == rs2 && we) ? wd : register[rs2];
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            register[0] <= 32'd0;
            register[1] <= 32'd12;
            register[2] <= 32'd22;
            register[3] <= 32'd32;
            register[4] <= 32'd42;
            register[5] <= 32'd52;
            register[6] <= 32'd62;
            register[7] <= 32'd72;
            register[8] <= 32'd82;
            for (i = 9; i < 32; i = i + 1'b1)
                register[i] <= 32'b0;
        end else if (we && rd != 5'b00000) begin
            register[rd] <= wd; 
        end
    end 
endmodule 