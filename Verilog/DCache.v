module DCache (
    input clk, reset,
    input en_cache,
    input [2:0] load_sel, // select for data alignment
    input [2:0] store_sel, // select for data alignment
    input [31:0] addr_d, // address for data cache
    input [31:0] addr_copy, // address to copy from upper level
    input [31:0] data_wr, // data to write
    input [31:0] data_mem, // data from memory
    input [31:0] data_copy, // data to copy from upper
    input WB_TL, // write back to memory or transfer to load
    input en_wr, // enable write operation
    output [31:0] data_out, // output data after alignment
    output [31:0] addr_mem  // address for memory operation
);

    localparam NUM_SETS = 64;
    localparam NUM_WAYS = 4;
    localparam OFFSET_BITS = 2;  // 4B block
    localparam INDEX_BITS  = 6;  // 64 sets
    localparam TAG_BITS    = 24; // 32 - 6 - 2

    localparam IDLE = 2'b00, MISS = 2'b01, FILL = 2'b10;
    reg [1:0] state, next_state;

    // Tag, Valid, and Data arrays
    reg [TAG_BITS-1:0]  tag_array   [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg                 valid_array [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [31:0]          data_array  [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg                 dirty       [0:NUM_WAYS-1][0:NUM_SETS-1];

    // LRU: 2-bit priority value per way per set (0 = most recent, 3 = least)
    reg [1:0] lru [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [1:0] least_recent_used;

    wire [0:NUM_WAYS-1]     way_hit;
    wire [INDEX_BITS-1:0]   index;
    wire [TAG_BITS-1:0]     tag;
    wire [31:0]             read_data;
    wire [31:0]             data_sel;
    wire [31:0]             addr_sel;
    wire                    write;

    assign tag = addr_d[31:8];
    assign index = addr_d[7:2];

    assign read_data = (en_wr) ? 32'b0 : 
                    (valid1[index] && tag_array[0][index] == tag) ? data_array[0][index] : 
                    (valid1[index] && tag_array[1][index] == tag) ? data_array[1][index] : 
                    (valid1[index] && tag_array[2][index] == tag) ? data_array[2][index] : 
                    (valid1[index] && tag_array[3][index] == tag) ? data_array[3][index] : data_mem;

    assign data_sel = (WB_TL) ? data_copy : data_wr;
    assign addr_sel = (WB_TL) ? addr_copy : addr_d;
    assign write = (WB_TL | en_wr) && en_cache;

    assign data_out = (load_sel == 3'b000) ?{{24{read_data[31]}}, read_data[7:0]} :
                    (load_sel == 3'b001) ? {24'b0, read_data[7:0]} :
                    (load_sel == 3'b010) ? {16'b0, read_data[15:0]} :
                    (load_sel == 3'b011) ? {{16{read_data[31]}}, read_data[15:0]} : read_data;

    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                lru[0][i] <= 2'b00;
                lru[1][i] <= 2'b00; 
                lru[2][i] <= 2'b00; 
                lru[3][i] <= 2'b00;

                dirty[0][i] <= 1'b0;
                dirty[1][i] <= 1'b0;
                dirty[2][i] <= 1'b0;
                dirty[3][i] <= 1'b0; 
            end
        end
        else if (!write) begin
            
        end
        
    end 
    
endmodule