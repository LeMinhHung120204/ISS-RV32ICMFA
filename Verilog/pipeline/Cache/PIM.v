`timescale 1ns/1ps
module PIM #(   // Policy info Memory
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 3
)(
    input   clk, rst_n, we,
    input   [ADDR_WIDTH-1:0] addr,
    input   [DATA_WIDTH-1:0] plru_in,
    output  [DATA_WIDTH-1:0] plru_out
);
    localparam DEPTH = 1 << ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] pim [0:DEPTH-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for(i = 0 ; i < DEPTH; i = i + 1) begin
                pim[i]  <= 3'd0;
            end 
        end 
        else begin
            if (we) begin
                pim[addr]  <= plru_in;
            end 
            // plru_out <= pim[addr];
        end 
    end 

    assign plru_out = pim[addr];
endmodule