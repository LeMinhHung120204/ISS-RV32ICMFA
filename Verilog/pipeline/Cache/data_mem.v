`timescale 1ns/1ps
module data_mem #(
    parameter DATA_W        = 32,
    parameter NUM_SETS      = 16,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,
    parameter CACHE_DATA_W  = (1<<WORD_OFF_W) * 32
)(
    input                       clk, rst_n, we,
    input   [INDEX_W-1:0]       index,
    input   [DATA_W-1:0]        din,
    input   [WORD_OFF_W-1:0]    word_off,
    // input   [3:0]                       write_wstrb,
    // output reg [CACHE_DATA_W-1:0]   dout
    output  [CACHE_DATA_W-1:0]  dout
);

    reg [CACHE_DATA_W-1:0] data_mem [0:NUM_SETS-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                data_mem[i] <= {DATA_W{1'b0}};
            end
        end 
        else begin
            if (we) begin
                data_mem[index][word_off*DATA_W +: DATA_W] <= din;
            end 
            // dout <= data_mem[index];
        end
    end

    assign dout = cache_data_mem[index];
endmodule