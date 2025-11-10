`timescale 1ns/1ps
module ICache #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  // 16 words/line
    parameter BYTE_OFF_W    = 2,  // 4B/word
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32
)(
    input clk, rst_n,
    // CPU -> Cache
    input [ADDR_W-1:0]          CPU_Addr,
    input                       CPU_Valid,
    // Mem -> Cache
    input [CACHE_DATA_W-1:0]    Mem_BlockData,
    input                       Mem_Ready,

    // Cache -> Mem
    output                      Mem_Valid,
    
    // Cache -> CPU
    output reg [DATA_W-1:0]    data_rdata,
    output                     hit
);
    localparam BO       = BYTE_OFF_W;
    localparam WO       = WORD_OFF_W;
    localparam IX       = INDEX_W;
    localparam TAG_LSB  = BO + WO + IX;
    localparam TAG_MSB  = ADDR_W-1;
    localparam IDX_MSB  = TAG_LSB-1;
    localparam IDX_LSB  = BO + WO;
    localparam WO_MSB   = IDX_LSB-1;

    wire [TAG_W-1:0]    tag         = CPU_Addr[TAG_MSB:TAG_LSB];
    wire [IX-1:0]       index       = CPU_Addr[IDX_MSB:IDX_LSB];
    wire [WO-1:0]       word_off    = CPU_Addr[WO_MSB:BO];
    wire [BO-1:0]       byte_off    = CPU_Addr[BO-1:0]; 

    wire [TAG_W-1:0]        tag_read0, tag_read1, tag_read2, tag_read3, tag_write;
    wire [CACHE_DATA_W-1:0] data_write;
    wire [CACHE_DATA_W-1:0] line_way0, line_way1, line_way2, line_way3;
    wire [NUM_WAYS-1:0]     way_hit, way_select;
    wire tag_we, data_we;

    reg [NUM_SETS-1:0] valid;
    //--------------------------------------- check hit ---------------------------------------
    assign way_hit[0]   = (tag == tag_read0) & valid[0];
    assign way_hit[1]   = (tag == tag_read1) & valid[1];
    assign way_hit[2]   = (tag == tag_read2) & valid[2];
    assign way_hit[3]   = (tag == tag_read3) & valid[3];
    assign hit          = | way_hit;

    //--------------------------------------- write data when miss ---------------------------------------
    assign tag_write    = tag;
    assign data_write   = Mem_BlockData;

    always @(*) begin
        case(way_hit)
            4'b0001: begin
                data_rdata = line_way0[word_off*DATA_W +: DATA_W];
            end
            4'b0010: begin
                data_rdata = line_way1[word_off*DATA_W +: DATA_W];
            end
            4'b0100: begin
                data_rdata = line_way2[word_off*DATA_W +: DATA_W];
            end
            4'b1000: begin
                data_rdata = line_way3[word_off*DATA_W +: DATA_W];
            end 
            default: data_rdata = 32'd0;
        endcase
    end 

    //--------------------------------------- way 0 ---------------------------------------
    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W)
    ) tag_way0(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (tag_we & way_select[0]),
        .index      (index),
        .din        (tag_write),
        .dout       (tag_read0)
    );

    data_mem #(
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS),
        .INDEX_W    (INDEX_W),
        .WORD_OFF_W (WORD_OFF_W)
    ) data_mem0(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (data_we & way_select[0]),
        .index      (index),
        .din        (data_write),
        .dout       (line_way0),
        .word_off   (word_off)
    );

    //--------------------------------------- way 1 ---------------------------------------
    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W)
    ) tag_way1(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (tag_we & way_select[1]),
        .index      (index),
        .din        (tag_write),
        .dout       (tag_read1)
    );

    data_mem #(
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS),
        .INDEX_W    (INDEX_W),
        .WORD_OFF_W (WORD_OFF_W)
    ) data_mem1(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (data_we & way_select[1]),
        .index      (index),
        .din        (data_write),
        .dout       (line_way1),
        .word_off   (word_off)
    );

    //--------------------------------------- way 2 ---------------------------------------
    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W)
    ) tag_way2(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (tag_we & way_select[2]),
        .index      (index),
        .din        (tag_write),
        .dout       (tag_read2)
    );

    data_mem #(
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS),
        .INDEX_W    (INDEX_W),
        .WORD_OFF_W (WORD_OFF_W)
    ) data_mem2(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (data_we & way_select[2]),
        .index      (index),
        .din        (data_write),
        .dout       (line_way2),
        .word_off   (word_off)
    );

    //--------------------------------------- way 3 ---------------------------------------
    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W)
    ) tag_way3(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (tag_we & way_select[3]),
        .index      (index),
        .din        (tag_write),
        .dout       (tag_read3)
    );

    data_mem #(
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS),
        .INDEX_W    (INDEX_W),
        .WORD_OFF_W (WORD_OFF_W)
    ) data_mem3(
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (data_we & way_select[3]),
        .index      (index),
        .din        (data_write),
        .dout       (line_way3),
        .word_off   (word_off)
    );

    //--------------------------------------- REPLACEMENT POLICY ---------------------------------------
    cache_replacement #(
        .N_WAYS (NUM_WAYS),
        .N_LINES(NUM_SETS)
    ) PLRU_replacement(
        .clk            (clk),
        .rst_n          (rst_n),
        .we             (),
        .way_hit        (way_hit),
        .addr           (index),
        .way_select     (way_select),
        .way_select_bin ()
    );

    //--------------------------------------- CACHE CONTROLLER ---------------------------------------
    icache_control icache_controller (
        .clk        (clk),
        .rst_n      (rst_n),
        .hit        (hit),
        .Mem_Ready  (Mem_Ready),
        .data_we    (data_we),
        .tag_we     (tag_we),
        .Mem_Valid  (Mem_Valid)
    );

endmodule 