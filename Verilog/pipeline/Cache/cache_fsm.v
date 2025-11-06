`timescale 1ns/1ps
module cache_fsm #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter INDEX_WIDTH       = 10, // 1024 lines
    parameter WORD_OFFSET_WIDTH = 2,  // 4 words/line
    parameter BYTE_OFFSET_WIDTH = 2,  // 4B/word
    // derived
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
    output     [CACHE_DATA_WIDTH-1:0]   Mem_Data,
    output reg [ADDR_WIDTH-1:0]         Mem_Addr,
    output reg                          Mem_rw,   // 1: write, 0: read
    output reg                          Mem_Valid,
    // Cache -> CPU
    output     [DATA_WIDTH-1:0]         data,
    output reg                          hit
);
    // -------- address fields (parametric) --------
    localparam BO = BYTE_OFFSET_WIDTH;
    localparam WO = WORD_OFFSET_WIDTH;
    localparam IX = INDEX_WIDTH;
    localparam TAG_LSB  = BO + WO + IX;
    localparam TAG_MSB  = ADDR_WIDTH-1;
    localparam IDX_MSB  = TAG_LSB-1;
    localparam IDX_LSB  = BO + WO;
    localparam TAGW     = ADDR_WIDTH - TAG_LSB;              // tag width
    localparam TAGPACKW = TAGW + 2;                          // {valid,dirty,tag}

    wire [TAGW-1:0] addr_tag  = CPU_Addr[TAG_MSB:TAG_LSB];
    wire [IX-1:0]   addr_idx  = CPU_Addr[IDX_MSB:IDX_LSB];
    wire [1:0]      word_off  = CPU_Addr[BO+WO-1:BO];

    // -------- memories --------
    reg                      data_we, tag_we;
    reg     [IX-1:0]             index;
    reg     [CACHE_DATA_WIDTH-1:0] data_write;
    wire    [CACHE_DATA_WIDTH-1:0] data_read;

    reg     [TAGPACKW-1:0] tag_write;
    wire    [TAGPACKW-1:0] tag_read;

    wire               tag_valid = tag_read[TAGPACKW-1];
    wire               tag_dirty = tag_read[TAGPACKW-2];
    wire    [TAGW-1:0] tag_bits  = tag_read[TAGW-1:0];

    // -------- CPU word mux/demux --------
    reg [DATA_WIDTH-1:0] cpu_res_data;
    assign data = cpu_res_data;

    // value driven to memory on write-back (the whole line)
    assign Mem_Data = data_read;

    // -------- FSM --------
    localparam IDLE = 2'd0, COMPARE_TAG= 2'd1, ALLOCATE = 2'd2, WRITE_BACK = 2'd3;
    reg [1:0] state, nstate;

    // state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            state <= IDLE;
        end 
        else begin
            state <= nstate;
        end
    end

    always @(*) begin
        // defaults
        nstate     = state;
        hit        = 1'b0;
        data_we    = 1'b0;
        tag_we     = 1'b0;
        Mem_Valid  = 1'b0;
        Mem_rw     = 1'b0;
        Mem_Addr   = {ADDR_WIDTH{1'b0}};
        index      = addr_idx;
        data_write = data_read;
        tag_write  = {tag_valid, tag_dirty, tag_bits};

        // CPU read data (from current line)
        case (word_off)
          2'b00: cpu_res_data   = data_read[31:0];
          2'b01: cpu_res_data   = data_read[63:32];
          2'b10: cpu_res_data   = data_read[95:64];
          default: cpu_res_data = data_read[127:96];
        endcase

        // if write, prepare modified line
        if (CPU_rw) begin
          case (word_off)
            2'b00: data_write[31:0]     = CPU_Data;
            2'b01: data_write[63:32]    = CPU_Data;
            2'b10: data_write[95:64]    = CPU_Data;
            2'b11: data_write[127:96]   = CPU_Data;
          endcase
        end

        case (state)
            IDLE: begin
                if (CPU_Valid) begin
                    nstate = COMPARE_TAG;
                end 
            end

            COMPARE_TAG: begin
                if (tag_valid && (tag_bits == addr_tag)) begin
                    // HIT 
                    hit = 1'b1;
                    if (CPU_rw) begin
                        data_we   = 1'b1;                         // write back to line
                        tag_we    = 1'b1;                         // set dirty
                        tag_write = {1'b1, 1'b1, addr_tag};
                    end
                    nstate = IDLE;
                end 
                else begin
                // ----- MISS -----
                    tag_we    = 1'b1;
                    tag_write = {1'b1, CPU_rw, addr_tag};       // valid=1, dirty=rw
                    Mem_Valid = 1'b1;                           // start miss transaction
                    if ((~tag_valid) | (~tag_dirty)) begin
                        // compulsory/clean miss -> allocate new line
                        nstate = ALLOCATE;
                    end 
                    else begin
                        // dirty miss -> write back old line
                        Mem_rw   = 1'b1; // write
                        Mem_Addr = {tag_bits, addr_idx, {BO+WO{1'b0}}};
                        nstate   = WRITE_BACK;
                    end
                end
            end

            ALLOCATE: begin
                if (Mem_Ready) begin
                // got the block -> fill and retry compare (for write-miss fixup)
                    data_we    = 1'b1;
                    data_write = Mem_BlockData;
                    nstate     = COMPARE_TAG;
                end
            end

            WRITE_BACK: begin
                if (Mem_Ready) begin
                // old line written -> request new line
                    Mem_Valid = 1'b1;
                    Mem_rw    = 1'b0; // read
                    nstate    = ALLOCATE;
                end
            end
        endcase
    end

    // -------- memories (single-port, direct-mapped) --------
    cache_data_mem u_data (
        .clk(clk),
        .rst_n(rst_n),
        .we(data_we),
        .index(index),
        .din(data_write),
        .dout(data_read)
    );

    tag_mem u_tag (
        .clk(clk),
        .rst_n(rst_n),
        .we(tag_we),
        .index(index),
        .tag_write(tag_write),
        .tag_read(tag_read)
    );
endmodule