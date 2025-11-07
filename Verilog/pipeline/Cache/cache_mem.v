`timescale 1ns/1ps
// 4 way, 16 lines, 64B
module cache_mem #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter N_WAYS        = 4,
    parameter N_SETS        = 16,
    parameter OFFSET_W      = 4, // 16 word 1 line
    parameter INDEX_W       = $clog2(N_SETS),
    parameter CACHE_DATA_W  = (1 << OFFSET_W) * 32
)(
    input clk, rst_n,

    // cpu <-> cache
    input                   data_valid, data_valid_reg,
    input   [ADDR_W-1:0]    data_addr, data_addr_reg,
    input   [DATA_W-1:0]    data_wdata_reg,
    input   [3:0]           data_wstrb_reg,
    output  [DATA_W-1:0]    data_rdata,     // chua co assign
    output                  data_ready,

    // cache <-> mem (write channel)
    input                           write_ready,
    output  [ADDR_W-1:0]            write_addr,
    output reg [CACHE_DATA_W-1:0]   write_wdata,
    // output  [3:0]           write_wstrb, // write back khong dung vi write ca line
    output                          write_valid,

    // cache <-> mem (read channel)
    output                  replace_valid,
    output  [ADDR_W-1:0]    replace_addr,
    input                   replace,
    input   [ADDR_W-1:0]    read_addr,
    input   [DATA_W-1:0]    read_data,

    // cache <-> cache_control
    input                   invalidate,
    // output                  wtbuf_empty, wtbuf_full,
    output                  write_hit, write_miss,
    output                  read_hit, read_miss
);
    localparam WO = OFFSET_W;
    localparam IX = INDEX_W;
    localparam TAG_LSB  = WO + IX;
    localparam TAG_MSB  = ADDR_W-1;
    localparam IDX_MSB  = TAG_LSB-1;
    localparam IDX_LSB  = WO;
    localparam TAG_W    = ADDR_W - TAG_LSB; 

    wire [N_WAYS-1:0]   way_hit, way_select;
    wire [1:0]          way_select_bin;
    wire [TAG_W-1:0]    tag, tag_read0, tag_read1, tag_read2, tag_read3;
    wire [INDEX_W-1:0]  index, index_reg;
    wire [OFFSET_W-1:0] offset;

    wire [CACHE_DATA_W-1:0] line_way0, line_way1, line_way2, line_way3;

    wire write_access, read_access;
    wire buffer_empty, buffer_full;
//    wire [] buffer_dout;

    reg [N_WAYS-1:0]    dirty, valid;
    reg [N_SETS - 1:0]  dirty_reg0, dirty_reg1, dirty_reg2, dirty_reg3;
    reg [N_SETS - 1:0]  valid_reg0, valid_reg1, valid_reg2, valid_reg3;
    reg [TAG_W-1:0]     tag_flush;

    assign tag          = data_addr_reg[TAG_MSB:TAG_LSB];
    assign index        = data_addr[IDX_MSB:IDX_LSB];
    assign index_reg    = data_addr_reg[IDX_MSB:IDX_LSB];
    assign offset       = data_addr_reg[WO-1:0];

    assign write_access     = ( |data_wstrb_reg) & data_valid_reg;
    assign read_access      = (~|data_wstrb_reg) & data_valid_reg;
    assign replace_valid    = (~|way_hit) & (write_ready) & (data_valid_reg) & (~replace);
    assign replace_addr     = data_addr;

    assign data_ready       = hit & data_valid_reg;

    // Read-After-Write (RAW) Hazard (pipeline) control
    wire                raw;
    reg                 write_hit_prev;
    reg [OFFSET_W-1:0]  offset_prev;
    reg [N_WAYS-1:0]     way_hit_prev;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            offset_prev     <= {(OFFSET_W){1'b0}};
            way_hit_prev    <= {(N_WAYS){1'b0}};
        end
        else begin
            offset_prev     <= offset;
            way_hit_prev    <= way_hit;
        end 
    end

    // valid and dirty
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            valid_reg0  <= {(N_SETS){1'b0}};
            valid_reg1  <= {(N_SETS){1'b0}};
            valid_reg2  <= {(N_SETS){1'b0}};
            valid_reg3  <= {(N_SETS){1'b0}};

            dirty_reg0  <= {(N_SETS){1'b0}};
            dirty_reg1  <= {(N_SETS){1'b0}};
            dirty_reg2  <= {(N_SETS){1'b0}};
            dirty_reg3  <= {(N_SETS){1'b0}};
        end 
        else begin
            // valid
            if (invalidate) begin
                valid_reg0  <= {(N_SETS){1'b0}};
                valid_reg1  <= {(N_SETS){1'b0}};
                valid_reg2  <= {(N_SETS){1'b0}};
                valid_reg3  <= {(N_SETS){1'b0}};
            end 
            else if (replace_valid) begin
                case(way_select)
                    4'b0001: valid_reg0[index_reg] <= 1'b1;
                    4'b0010: valid_reg1[index_reg] <= 1'b1;
                    4'b0100: valid_reg2[index_reg] <= 1'b1;
                    4'b1000: valid_reg3[index_reg] <= 1'b1;
                endcase
            end 

            // dirty
            if (write_valid) begin
                case(way_select)
                    4'b0001: dirty_reg0[index_reg] <= 1'b0;
                    4'd0010: dirty_reg1[index_reg] <= 1'b0;
                    4'b0100: dirty_reg2[index_reg] <= 1'b0;
                    4'b1000: dirty_reg3[index_reg] <= 1'b0;
                endcase
            end 
            else if (write_access & hit) begin
                case(way_select)
                    4'b0001: dirty_reg0[index_reg] <= 1'b1;
                    4'b0010: dirty_reg1[index_reg] <= 1'b1;
                    4'b0100: dirty_reg2[index_reg] <= 1'b1;
                    4'b1000: dirty_reg3[index_reg] <= 1'b1;
                endcase
            end 
        end 
    end 
    always @(posedge clk) begin
        dirty[0] <= dirty_reg0[index];
        dirty[1] <= dirty_reg1[index];
        dirty[2] <= dirty_reg2[index];
        dirty[3] <= dirty_reg3[index];

        if (invalidate) begin
            valid <= 3'd0;
        end 
        else begin
            valid[0] <= valid_reg0[index];
            valid[1] <= valid_reg1[index];
            valid[2] <= valid_reg2[index];
            valid[3] <= valid_reg3[index];
        end 
    end 
    // flush
    always @(*) begin
        case(way_select_bin)
            2'd0: begin
                tag_flush   = tag_read0;
                write_wdata = line_way0; 
            end 
            2'd1: begin
                tag_flush   = tag_read1;
                write_wdata = line_way1;
            end 
            2'd2: begin
                tag_flush   = tag_read2;
                write_wdata = line_way2;
            end 
            2'd3: begin 
                tag_flush   = tag_read3;
                write_wdata = line_way3;
            end 
        endcase
    end 
    assign write_valid  = data_valid_reg & ~(|way_hit) & dirty[way_select_bin];
    assign write_addr   = {tag_flush, index_reg, 6'd0};

    // RAW
    assign raw          = write_hit_prev & (way_hit_prev == way_hit) & (offset_prev == offset) & read_access;

    // Check hit
    assign hit          = |way_hit & (~replace) & (~raw);


    // output for cache control
    assign write_hit    = data_ready & write_access;
    assign write_miss   = data_ready & (~hit & write_access);    // write_miss luon = 0
    assign read_hit     = data_ready & read_access;
    assign read_miss    = replace_valid;

    assign way_hit[0]   = (tag == tag_read0) & valid[0];
    assign way_hit[1]   = (tag == tag_read1) & valid[1];
    assign way_hit[2]   = (tag == tag_read2) & valid[2];
    assign way_hit[3]   = (tag == tag_read3) & valid[3];

    // way 1
    data_mem #(
        .INDEX_W(INDEX_W),
        .CACHE_DATA_WIDTH(CACHE_DATA_W),
        .NUM_CACHE_LINES(N_SETS)
    ) data_mem0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_hit[0]),
        .index  ((write_access & way_hit[0]) ? index_reg : index),
        .din    ((replace) ? read_data : data_wdata_reg),
        .dout   (line_way0)
    );

    tag_mem #(
        .INDEX_W(INDEX_W),
        .TAG_W(TAG_W),
        .NUM_CACHE_LINES(N_SETS)
    ) tag_mem0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_select[0] & replace_valid),
        .index  (index),
        .din    (tag),
        .dout   (tag_read0)
    );

    // way 2
    data_mem #(
        .INDEX_W(INDEX_W),
        .CACHE_DATA_WIDTH(CACHE_DATA_W),
        .NUM_CACHE_LINES(N_SETS)
    ) data_mem1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_hit[1]),
        .index  ((write_access & way_hit[1]) ? index_reg : index),
        .din    ((replace) ? read_data : data_wdata_reg),
        .dout   (line_way1)
    );

    tag_mem #(
        .INDEX_W(INDEX_W),
        .TAG_W(TAG_W),
        .NUM_CACHE_LINES(N_SETS)
    ) tag_mem1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_select[1] & replace_valid),
        .index  (index),
        .din    (tag),
        .dout   (tag_read1)
    );

    // way 3
    data_mem #(
        .INDEX_W(INDEX_W),
        .CACHE_DATA_WIDTH(CACHE_DATA_W),
        .NUM_CACHE_LINES(N_SETS)
    ) data_mem2 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_hit[2]),
        .index  ((write_access & way_hit[2]) ? index_reg : index),
        .din    ((replace) ? read_data : data_wdata_reg),
        .dout   (line_way2)
    );

    tag_mem #(
        .INDEX_W(INDEX_W),
        .TAG_W(TAG_W),
        .NUM_CACHE_LINES(N_SETS)
    ) tag_mem2 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_select[2] & replace_valid),
        .index  (index),
        .din    (tag),
        .dout   (tag_read2)
    );

    // way 4
    data_mem #(
        .INDEX_W(INDEX_W),
        .CACHE_DATA_WIDTH(CACHE_DATA_W),
        .NUM_CACHE_LINES(N_SETS)
    ) data_mem3 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_hit[3]),
        .din    ((replace) ? read_data : data_wdata_reg),
        .index  ((write_access & way_hit[3]) ? index_reg : index),
        .dout   (line_way3)
    );

    tag_mem #(
        .INDEX_W(INDEX_W),
        .TAG_W(TAG_W),
        .NUM_CACHE_LINES(N_SETS)
    ) tag_mem3 (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (way_select[3] & replace_valid),
        .index  (index),
        .din    (tag),
        .dout   (tag_read3)
    );

    cache_replacement #(
        .N_WAYS(N_WAYS),
        .N_LINES(N_SETS)
    ) cache_replacement (
        .clk        (clk),
        .rst_n      (rst_n | invalidate),
        .we         (data_ready),
        .way_hit    (way_hit),
        .addr       (index_reg),
        .way_select (way_select),
        .way_select_bin(way_select_bin)
    );
endmodule 