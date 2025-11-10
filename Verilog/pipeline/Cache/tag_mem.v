`timescale 1ns/1ps
module tag_mem #(
    parameter NUM_SETS      = 16,
    parameter TAG_W         = 24,
    parameter INDEX_W       = $clog2(NUM_SETS)
)(
    input                   clk, rst_n, we,
    input   [INDEX_W-1:0]   index,
    input   [TAG_W-1:0]     din,
    output  [TAG_W-1:0]     dout
);

    reg [TAG_W-1:0] tag_mem [0:NUM_SETS-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                tag_mem[i] <= {TAG_W{1'b0}};
            end
        end 
        else begin
            if (we) begin
                tag_mem[index] <= din;
            end 
            // dout <= tag_mem[index];
        end
    end
    assign dout = tag_mem[index];
endmodule