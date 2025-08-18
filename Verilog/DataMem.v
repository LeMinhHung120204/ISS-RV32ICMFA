`timescale 1ns/1ps

module DataMem #(
    parameter WIDTH_ADDR = 32,
    parameter Data_WIDTH = 32
)(
    input clk, rst_n, MemWrite,
    input [WIDTH_ADDR - 1:0] addr,
    input [Data_WIDTH - 1:0] data_in,
    output reg [Data_WIDTH - 1:0] rd
);
    reg [Data_WIDTH - 1:0] mem [0:WIDTH_ADDR - 1];
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for(i = 0 ; i < WIDTH_ADDR; i = i + 1'b1) begin
                mem[i] <= 32'd0;
            end 
        end
        else begin
            if (MemWrite) begin
                mem[addr] <= data_in;
            end
            else begin
                rd <= mem[addr];
            end  
        end 
    end

endmodule 