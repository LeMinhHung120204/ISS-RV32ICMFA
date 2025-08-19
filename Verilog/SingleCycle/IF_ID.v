`timescale 1ns/1ps
module IF_ID #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input  [DATA_WIDTH - 1:0] RDF, 
    input  [ADDR_WIDTH - 1:0] PCF,
    input  [ADDR_WIDTH - 1:0] PCPlus4F,
    output [DATA_WIDTH - 1:0] InstrD,
    output [DATA_WIDTH - 1:0] PCD,
    output [ADDR_WIDTH - 1:0] PCPlus4D
);
    reg [ADDR_WIDTH - 1:0] reg_PCD;
    reg [ADDR_WIDTH - 1:0] reg_PCPlus4D;
    reg [DATA_WIDTH - 1:0] reg_InstrD;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_PCD         <= 32'd0;
            reg_PCPlus4D    <= 32'd0;
            reg_InstrD      <= 32'd0;
        end 
        else begin
            reg_PCD         <= PCF;
            reg_PCPlus4D    <= RDF;
            reg_InstrD      <= PCPlus4F;
        end 
    end 

    assign InstrD    = reg_InstrD;
    assign PCD       = reg_PCD;
    assign PCPlus4D  = reg_PCPlus4D;
endmodule