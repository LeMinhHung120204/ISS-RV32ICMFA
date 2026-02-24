`timescale 1ns/1ps
module access #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_SETS      = 16,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  // 16 words/line
    parameter BYTE_OFF_W    = 2,  // 4B/word
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W
)(
    input   [ADDR_W-1:0]        cpu_addr
,   input   [ADDR_W-1:0]        ac_addr
,   input   [ADDR_W-1:0]        dcache_req_moesi_addr

,   output  [TAG_W-1:0]         cpu_tag
,   output  [INDEX_W-1:0]       cpu_index
,   output  [WORD_OFF_W-1:0]    cpu_word_off
,   output  [BYTE_OFF_W-1:0]    cpu_byte_off

,   output  [TAG_W-1:0]         ac_tag
,   output  [INDEX_W-1:0]       ac_index
,   output  [INDEX_W-1:0]       dcache_req_moesi_index
);
    localparam BO       = BYTE_OFF_W;
    localparam WO       = WORD_OFF_W;
    localparam IX       = INDEX_W;
    localparam TAG_LSB  = BO + WO + IX;
    localparam TAG_MSB  = ADDR_W-1;
    localparam IDX_MSB  = TAG_LSB-1;
    localparam IDX_LSB  = BO + WO;
    localparam WO_MSB   = IDX_LSB-1;

    assign cpu_tag                  = cpu_addr  [TAG_MSB:TAG_LSB];
    assign ac_tag                   = ac_addr   [TAG_MSB:TAG_LSB];
    assign cpu_index                = cpu_addr  [IDX_MSB:IDX_LSB];
    assign ac_index                 = ac_addr   [IDX_MSB:IDX_LSB];
    assign cpu_word_off             = cpu_addr  [WO_MSB:BO];
    assign cpu_byte_off             = cpu_addr  [BO-1:0]; 

    assign dcache_req_moesi_index   = dcache_req_moesi_addr[IDX_MSB:IDX_LSB];
endmodule