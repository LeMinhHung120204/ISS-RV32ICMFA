`timescale 1ns/1ps
module IF_ID #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input   clk, rst_n, EN, D_Flush,
    input   [DATA_WIDTH - 1:0] F_RD, 
    input   [ADDR_WIDTH - 1:0] F_PC,
    input   [ADDR_WIDTH - 1:0] F_PCPlus4,
    output  [DATA_WIDTH - 1:0] D_Instr,
    output  [DATA_WIDTH - 1:0] D_PC,
    output  [ADDR_WIDTH - 1:0] D_PCPlus4
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
            if (D_Flush) begin
                reg_PCD         <= 32'd0;
                reg_PCPlus4D    <= 32'd0;
                reg_InstrD      <= 32'd0;
            end 
            else if (~EN) begin
                reg_PCD         <= F_PC;
                reg_PCPlus4D    <= F_PCPlus4;
                reg_InstrD      <= F_RD;
            end
        end 
    end 

    assign D_Instr    = reg_InstrD;
    assign D_PC       = reg_PCD;
    assign D_PCPlus4  = reg_PCPlus4D;
endmodule