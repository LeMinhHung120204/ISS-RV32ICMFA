`timescale 1ns/1ps

module DataMem #(
    parameter WIDTH_ADDR = 8,
    parameter Data_WIDTH = 32
)(
    input clk, rst_n, MemWrite,
    input [WIDTH_ADDR - 1:0] addr,
    input [Data_WIDTH - 1:0] data_in,
    output [Data_WIDTH - 1:0] rd
);
    reg [Data_WIDTH - 1:0] mem [0:(1 << WIDTH_ADDR) - 1];
    
    integer i;
    always @(negedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for(i = 0 ; i < (1 << WIDTH_ADDR); i = i + 1'b1) begin
                mem[i] <= 32'd0;
            end 
        end
        else begin
            if (MemWrite) begin
                mem[addr] <= data_in;
            end
            // else begin
            //     rd <= mem[addr];
            // end  
        end 
    end
    assign rd = mem[addr];

endmodule 