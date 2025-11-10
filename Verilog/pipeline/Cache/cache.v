`timescale 1ns/1ps
module cache #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_SETS      = 16,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  // 16 words/line
    parameter BYTE_OFF_W    = 2,  // 4B/word
    parameter TAG_W         = ADDR_W - INDEX_WIDTH - WORD_OFF_W - BYTE_OFF_W;
    parameter CACHE_DATA_W  = (1 << WORD_OFFSET_WIDTH) * 32
)(
    input clk, rst_n,
    // CPU -> Cache
    input [DATA_W-1:0]          CPU_Data,
    input [ADDR_W-1:0]          CPU_Addr,
    input                       CPU_rw,     // 1: write, 0: read
    input                       CPU_Valid,
    // Mem -> Cache
    input [CACHE_DATA_W-1:0]    Mem_BlockData,
    input                       Mem_Ready,

    // Cache -> Mem
    output  [CACHE_DATA_W-1:0]  Mem_Data,
    output  [ADDR_W-1:0]        Mem_Addr,
    output                      Mem_rw,   // 1: write, 0: read
    output                      Mem_Valid,
    // Cache -> CPU
    output  [DATA_W-1:0]       data,
    output                     hit
);
    localparam BO = BYTE_OFF_W;
    localparam WO = WORD_OFF_W;
    localparam IX = INDEX_W;
    localparam TAG_LSB  = BO + WO + IX;
    localparam TAG_MSB  = ADDR_W-1;
    localparam IDX_MSB  = TAG_LSB-1;
    localparam IDX_LSB  = BO + WO;
    localparam WO_MSB   = IDX_LSB-1;

    wire [TAG_W-1:0]    tag         = CPU_Addr[TAG_MSB:TAG_LSB];
    wire [IX-1:0]       index       = CPU_Addr[IDX_MSB:IDX_LSB];
    wire [WO-1:0]       word_off    = CPU_Addr[WO_MSB:BO];
    wire [BO-1:0]       byte_off    = CPU_Addr[BO-1:0]; 

    reg [NUM_SETS-1:0] dirty, valid;
    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W)
    ) tag_way0(
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (),
        .index  (),
        .din    (),
        .dout   ()
    );
endmodule 