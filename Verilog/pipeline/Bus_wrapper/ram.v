`timescale 1ns/1ps
// from Lee Min Hunz with luv
module ram #(
    parameter DATA_W        = 32,
    parameter ADDR_W        = 8,
    parameter RESET_VALUE   = 32'h0000_0000
)(
    input               clk 
,   input               rst_n
,   input               we
,   input               re
,   input  [ADDR_W-1:0] w_addr
,   input  [ADDR_W-1:0] r_addr
,   input  [DATA_W-1:0] w_data
,   output [DATA_W-1:0] r_data
,   output reg          valid
);
    reg [DATA_W-1:0] mem [0:(1 << ADDR_W) - 1];
    reg [DATA_W-1:0] OutMem;

    integer i;
    initial begin
        for(i = 0; i < (1 << ADDR_W); i = i + 1) begin
            mem[i] = RESET_VALUE;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            OutMem  <= RESET_VALUE;
            valid   <= 1'b0;
        end
        else begin
            if (we) begin
                mem[w_addr] <= w_data; 
            end 
            
            if (re) begin
                OutMem <= mem[r_addr];
                valid  <= 1'b1;
            end 
            else begin
                valid <= 1'b0;
            end 
        end
    end

    assign r_data = OutMem;

endmodule