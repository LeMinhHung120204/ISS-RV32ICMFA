`timescale 1ns/1ps

// 16 sets, 64 bytes per block line, 4 ways
module ICache #(
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,    // 1 instruction = 32-bit (RV32I)
    // Cache geometry
    parameter SETS             = 16,    // 16 sets
    parameter WAYS             = 4,     // 4-way assoc
    parameter LINE_BYTES       = 64,    // 64B per line
    // Derived
    parameter INDEX_BITS       = $clog2(SETS),                          // = 4
    parameter BYTE_OFFSET_BITS = 2,                     
    parameter WORD_OFFSET_BITS = $clog2(LINE_BYTES/4),                  // = 4
    parameter OFFSET_BITS      = BYTE_OFFSET_BITS + WORD_OFFSET_BITS,   // = 6
    parameter TAG_BITS         = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS, // = 22
    parameter LINE_BITS        = LINE_BYTES * 8                         // = 512
)(
    input   clk, rst_n,
    input   [ADDR_WIDTH-1:0] InstrAddr,
    input   [DATA_WITDH-1:0] DataMem,
    output  [DATA_WITDH-1:0] Data,
    output  hit
);
    // valid & tag for each way
    reg                 valid0 [0:SETS-1];
    reg                 valid1 [0:SETS-1];
    reg                 valid2 [0:SETS-1];
    reg                 valid3 [0:SETS-1];

    reg [TAG_BITS-1:0]  tag0   [0:SETS-1];
    reg [TAG_BITS-1:0]  tag1   [0:SETS-1];
    reg [TAG_BITS-1:0]  tag2   [0:SETS-1];
    reg [TAG_BITS-1:0]  tag3   [0:SETS-1];

     // data line per way: 64B = 512-bit
    reg [LINE_BITS-1:0] data0  [0:SETS-1];
    reg [LINE_BITS-1:0] data1  [0:SETS-1];
    reg [LINE_BITS-1:0] data2  [0:SETS-1];
    reg [LINE_BITS-1:0] data3  [0:SETS-1];

    // OFFSET = BYTE_OFFSET_BITS + WORD_OFFSET_BITS
    wire [INDEX_BITS-1:0]       index;
    wire [TAG_BITS-1:0]         tag;
    wire [WORD_OFFSET_BITS-1:0] word_offset;
    wire [BYTE_OFFSET_BITS-1:0] byte_offset;

    assign byte_offset = InstrAddr[BYTE_OFFSET_BITS-1:0];                                       // [1:0]
    assign word_offset = InstrAddr[BYTE_OFFSET_BITS + WORD_OFFSET_BITS -1 : BYTE_OFFSET_BITS];  // [5:2]
    assign index       = InstrAddr[OFFSET_BITS + INDEX_BITS -1 : OFFSET_BITS];                  // [9:6]
    assign tag         = InstrAddr[ADDR_WIDTH-1 : ADDR_WIDTH - TAG_BITS];                       // [31:10]

    

endmodule 