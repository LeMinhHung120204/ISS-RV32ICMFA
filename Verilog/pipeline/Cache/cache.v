`timescale 1ns/1ps
module cache #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter INDEX_WIDTH       = 10, // 1024 lines
    parameter WORD_OFFSET_WIDTH = 2,  // 4 words/line
    parameter BYTE_OFFSET_WIDTH = 2,  // 4B/word
    parameter CACHE_DATA_WIDTH  = (1 << WORD_OFFSET_WIDTH) * 32
)(
    input clk, rst_n,
    // CPU -> Cache
    input [DATA_WIDTH-1:0]          CPU_Data,
    input [ADDR_WIDTH-1:0]          CPU_Addr,
    input                           CPU_rw,     // 1: write, 0: read
    input                           CPU_Valid,
    // Mem -> Cache
    input [CACHE_DATA_WIDTH-1:0]    Mem_BlockData,
    input                           Mem_Ready,

    // Cache -> Mem
    output  [CACHE_DATA_WIDTH-1:0] Mem_Data,
    output  [ADDR_WIDTH-1:0]       Mem_Addr,
    output                         Mem_rw,   // 1: write, 0: read
    output                         Mem_Valid,
    // Cache -> CPU
    output  [DATA_WIDTH-1:0]       data,
    output                         hit
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

    wire [TAGW-1:0] addr_tag, addr_tag_delay;
    wire [IX-1:0]   addr_idx, addr_idx_delay;
    wire [1:0]      word_off, word_off_delay;

    wire [TAGPACKW-1:0] tag_read0, tag_read1, tag_read2, tag_read3;

    wire check_tag_delay, check_tag0, check_tag1, check_tag2, check_tag3;

    reg [DATA_WIDTH-1:0] delay_data;
    reg [ADDR_WIDTH-1:0] delay_addr;

    assign addr_tag         = CPU_Addr[TAG_MSB:TAG_LSB];
    assign addr_idx         = CPU_Addr[IDX_MSB:IDX_LSB];
    assign word_off         = CPU_Addr[BO+WO-1:BO];

    assign addr_tag_delay   = delay_addr[TAG_MSB:TAG_LSB];
    assign addr_idx_delay   = delay_addr[IDX_MSB:IDX_LSB];
    assign word_off_delay   = delay_addr[BO+WO-1:BO];

    assign check_tag_delay  = (addr_tag == addr_tag_delay)  ? 1'b1 : 1'b0;
    assign check_tag0       = (addr_tag == tag_read0)       ? 1'b1 : 1'b0;
    assign check_tag1       = (addr_tag == tag_read1)       ? 1'b1 : 1'b0;
    assign check_tag2       = (addr_tag == tag_read2)       ? 1'b1 : 1'b0;
    assign check_tag3       = (addr_tag == tag_read3)       ? 1'b1 : 1'b0;

    assign hit = check_tag_delay | check_tag0 | check_tag1 | check_tag2 | check_tag3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_data <= 32'd0;
            delay_addr <= 32'd0;
        end 
        else begin
            delay_data <= CPU_Data;
            delay_addr <= CPU_Addr;
        end
    end

    cache_data_mem u_data0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (),
        .index  (addr_idx),
        .din    (delay_data),
        .dout   ()
    );

    cache_data_mem u_data1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (),
        .index  (addr_idx),
        .din    (delay_data),
        .dout   ()
    );

    cache_data_mem u_data2 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (),
        .index  (addr_idx),
        .din    (delay_data),
        .dout   ()
    );

    cache_data_mem u_data3 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (),
        .index  (addr_idx),
        .din    (delay_data),
        .dout   ()
    );

    tag_mem u_tag0 (
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (),
        .index      (addr_idx),
        .tag_write  (),
        .tag_read   (tag_read0)
    );

    tag_mem u_tag1 (
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (),
        .index      (addr_idx),
        .tag_write  (),
        .tag_read   (tag_read1)
    );

    tag_mem u_tag2 (
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (),
        .index      (addr_idx),
        .tag_write  (),
        .tag_read   (tag_read2)
    );

    tag_mem u_tag3 (
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (),
        .index      (addr_idx),
        .tag_write  (),
        .tag_read   (tag_read3)
    );
    
endmodule 