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
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32,

    parameter ID_W          = 2,    // ICACHE1: 2'b10, ICACHE2: 2'b11;
    parameter USER_W        = 4,
    parameter STRB_W        = (DATA_W/8)

)(
    input ACLK, ARESETn,
    input      [ADDR_W-1:0] CPU_Addr,
    output reg [DATA_W-1:0] data_rdata,

    // (cache <-> cache L2)
    // AW channel 
    output  [ID_W-1:0]      oAWID,
    output  [ADDR_W-1:0]    oAWADDR,
    output  [7:0]           oAWLEN,
    output  [2:0]           oAWSIZE,
    output  [1:0]           oAWBURST,
    output                  oAWLOCK,
    output  [3:0]           oAWCACHE,
    output  [2:0]           oAWPROT,
    output  [3:0]           oAWQOS,
    output  [3:0]           oAWREGION,
    output  [USER_W-1:0]    oAWUSER,
    output                  oAWVALID,
    input                   iAWREADY,

    // W channel
    output  [DATA_W-1:0]    oWDATA,
    output  [STRB_W-1:0]    oWSTRB,
    output                  oWLAST,
    output  [USER_W-1:0]    oWUSER,
    output                  oWVALID,
    input                   iWREADY,

    // B channel
    input   [ID_W-1:0]      iBID,
    input   [1:0]           iBRESP,
    input   [USER_W-1:0]    iBUSER,
    input                   iBVALID,
    output                  oBREADY,

    // AR channel
    output  [ID_W-1:0]      oARID,
    output  [ADDR_W-1:0]    oARADDR,
    output  [7:0]           oARLEN,
    output  [2:0]           oARSIZE,
    output  [1:0]           oARBURST,
    output                  oARLOCK,
    output  [3:0]           oARCACHE,
    output  [2:0]           oARPROT,
    output  [3:0]           oARQUOS,
    output  [USER_W-1:0]    oARUSER,
    output                  oARVALID,
    input                   iARREADY,

    // R channel
    input   [ID_W-1:0]      iRID,
    input   [DATA_W-1:0]    iRDATA,
    input   [1:0]           iRRESP,
    input                   iRLAST,
    input   [USER_W-1:0]    iRUSER,
    input                   iRVALID,
    output                  oRREADY
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
    wire tag_we, data_we, hit;

    reg [NUM_SETS-1:0] valid0, valid1, valid2, valid3;
    //--------------------------------------- check hit ---------------------------------------
    assign way_hit[0]   = (tag == tag_read0) & valid0[index];
    assign way_hit[1]   = (tag == tag_read1) & valid1[index];
    assign way_hit[2]   = (tag == tag_read2) & valid2[index];
    assign way_hit[3]   = (tag == tag_read3) & valid3[index];
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk        (ACLK),
        .rst_n      (ARESETn),
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
        .clk            (ACLK),
        .rst_n          (ARESETn),
        .we             (hit),
        .way_hit        (way_hit),
        .addr           (index),
        .way_select     (way_select),
        .way_select_bin ()
    );

    //--------------------------------------- CACHE CONTROLLER ---------------------------------------
    icache_controller icache_controller (
        .clk        (ACLK),
        .rst_n      (ARESETn),
        .hit        (hit),
        .data_we    (data_we),
        .tag_we     (tag_we),

        // cache <-> mem
        .oAWID      (oAWID    ),
        .oAWLEN     (oAWLEN   ),
        .oAWSIZE    (oAWSIZE  ),
        .oAWBURST   (oAWBURST ),
        .oAWLOCK    (oAWLOCK  ),
        .oAWCACHE   (oAWCACHE ),
        .oAWPROT    (oAWPROT  ),
        .oAWQOS     (oAWQOS   ),
        .oAWREGION  (oAWREGION),
        .oAWUSER    (oAWUSER  ),
        .oAWVALID   (oAWVALID ),

        .oWSTRB     (oWSTRB ),
        .oWLAST     (oWLAST ),
        .oWUSER     (oWUSER ),
        .oWVALID    (oWVALID),

        .oBREADY    (oBREADY),

        .iARREADY   (iARREADY),
        .oARID      (oARID   ),
        .iARSIZE    (iARSIZE ),
        .oARBURST   (oARBURST),
        .oARCACHE   (oARCACHE),
        .oARQUOS    (oARQUOS ),
        .oARUSER    (oARUSER ),
        .oARVALID   (oARVALID),

        .iRLAST     (iRLAST ),
        .oRREADY    (oRREADY)
    );

endmodule 