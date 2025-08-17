module Ins_Mem #(
    parameter WIDTH_ADDR = 32,
    parameter WIDTH_DATA = 32
)(
    input clk, rst_n,
    input [WIDTH_ADDR - 1:0] addr,
    output [WIDTH_DATA -1:0] instruction
);
    reg [WIDTH_DATA - 1:0] mem [0:WIDTH_ADDR - 1];

    always @(posedge clk or negedge rst_n) begin
        instruction <= mem[addr];
    end 
endmodule 