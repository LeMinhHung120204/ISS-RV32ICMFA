`timescale 1ns/1ps
module cache_data_mem #(
    parameter DATA_WITDH        = 32,
    parameter INDEX_WIDTH       = 10,
    parameter CACHE_DATA_WIDTH  = 128,  // 2^(WORD_OFFSET_WIDTH) = 4 WORD = 4*32 bits = 128 bits
    parameter NUM_CACHE_LINES   = 1024  // 2^(INDEX_WIDTH) = 1024 lines
)(
    input   clk, rst_n, we,
    input   [INDEX_WIDTH-1:0] index,
    input   [CACHE_DATA_WIDTH-1:0] din,
    output  [DATA_WITDH-1:0] dout
);

    reg [CACHE_DATA_WIDTH-1:0] cache_data_mem [0:NUM_CACHE_LINES-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_CACHE_LINES; i = i + 1) begin
                cache_data_mem[i] <= {CACHE_DATA_WIDTH{1'b0}};
            end
        end 
        else begin
            if (we) begin
                cache_data_mem[index] <= din;
            end 
        end
    end

    assign dout = cache_data_mem[index];
endmodule