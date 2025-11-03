`timescale 1ns/1ps
module ICache #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter INDEX_WIDTH       = 10, // 1024 lines
    parameter WORD_OFFSET_WIDTH = 2,  // 4 words/line
    parameter BYTE_OFFSET_WIDTH = 2,  // 4B/word
    parameter CACHE_DATA_WIDTH  = (1 << WORD_OFFSET_WIDTH) * 32
)(
    input   clk, rst_n,
    // CPU request (CPU -> Cache)
    input   [ADDR_WIDTH-1:0] InstrAddr,

    // Memory controller response (Memory -> Cache)
    input   [(1<<WORD_OFFSET_WIDTH)*32-1:0] Mem_BlockData, // 128 bits
    input   Mem_Ready,

    // Cache -> Mem
    output  [ADDR_WIDTH-1:0] Mem_Addr,
    output  Mem_Valid,

    // Cache results (Cache -> CPU)
    output  [DATA_WIDTH-1:0] Data,
    output  hit
);
    // -------- address fields (parametric) --------
    localparam BO = BYTE_OFFSET_WIDTH;
    localparam WO = WORD_OFFSET_WIDTH;
    localparam IX = INDEX_WIDTH;
    localparam TAG_LSB  = BO + WO + IX;
    localparam TAG_MSB  = ADDR_WIDTH-1;
    localparam IDX_MSB  = TAG_LSB-1;
    localparam IDX_LSB  = BO + WO;
    localparam TAGW     = ADDR_WIDTH - TAG_LSB; // tag width
    localparam TAGPACKW = TAGW + 2;             // {valid,dirty,tag}

    wire [TAGW-1:0] addr_tag  = CPU_Addr[TAG_MSB:TAG_LSB];
    wire [IX-1:0]   addr_idx  = CPU_Addr[IDX_MSB:IDX_LSB];
    wire [1:0]      word_off  = CPU_Addr[BO+WO-1:BO];
    
endmodule 