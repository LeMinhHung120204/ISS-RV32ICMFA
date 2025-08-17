module Icache #(
    parameter NUM_SETS    = 64,
    parameter NUM_WAYS    = 4,
    parameter OFFSET_BITS = 6,    // 64B
    parameter INDEX_BITS  = 6,    // 64 sets
    parameter TAG_BITS    = 32 - OFFSET_BITS - INDEX_BITS
)(
    input clk, rst_n,  
);
    
endmodule 