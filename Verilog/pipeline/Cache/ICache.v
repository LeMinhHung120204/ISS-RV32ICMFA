`timescale 1ns/1ps
module ICache #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32, 
    // Cache geometry
    parameter Tag_WIDTH         = 18,
    parameter INDEX_WIDTH       = 10,
    parameter WORD_OFFSET_WIDTH = 2,
    parameter BYTE_OFFSET_WIDTH = 2
)(
    input   clk, rst_n,
    input   [ADDR_WIDTH-1:0] InstrAddr,
    input   [DATA_WIDTH-1:0] DataMem,

    // CPU request (CPU -> Cache controller)
    input   [DATA_WIDTH-1:0] CPU_Data,  // Used when write 
    input   [ADDR_WIDTH-1:0] CPU_Addr,
    input   rw,         // 1 - write, 0 - read
    input   CPU_Valid,

    // Memory controller response (Memory -> Cache controller)
    input   [(1<<WORD_OFFSET_WIDTH)*32-1:0] Mem_BlockData, // 128 bits
    input   Mem_Ready,

    // Memory request (Cache controller -> Memory)
    output  [DATA_WIDTH-1:0] Mem_Data,  // Used when write
    output  [ADDR_WIDTH-1:0] Mem_Addr,
    output  Mem_rw,     // 1 - write, 0 - read
    output  Mem_Valid,

    // Cache results (Cache controller -> CPU)
    output  [DATA_WITDH-1:0] Data,
    output  hit
);
    
endmodule 