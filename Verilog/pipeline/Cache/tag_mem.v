`timescale 1ns/1ps
module tag_mem #(
    parameter INDEX_WIDTH       = 4,
    parameter TAG_W             = 24,
    parameter NUM_CACHE_LINES   = 16
)(
    input                           clk, rst_n, we,
    input       [INDEX_WIDTH-1:0]   index,
    input       [TAG_W-1:0]         din,
    output reg  [TAG_W-1:0]         dout
);

    reg [TAG_W-1:0] tag_mem [0:NUM_CACHE_LINES-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_CACHE_LINES; i = i + 1) begin
                tag_mem[i] <= {TAG_W{1'b0}};
            end
        end 
        else begin
            if (we) begin
                tag_mem[index] <= din;
            end 
            dout <= tag_mem[index];
        end
    end
endmodule