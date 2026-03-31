`timescale 1ns / 1ps
// from Lee Min Hunz with luv
// ============================================================================
// BTB - Branch Target Buffer
// ============================================================================
// 4-way set associative, 8 sets. Stores branch target addresses.
// Uses PLRU replacement policy.
// On hit: returns predicted target address.
// Updated when branch/jump executes in EX stage.
// ============================================================================
module BTB #(
    parameter W_ADDR = 32
)(
    input                   clk, rst_n
,   input [W_ADDR-1:0]      F_PC
,   output reg [W_ADDR-1:0] pc_prediction
,   output                  hit

,   input [W_ADDR-1:0]      E_PC           
,   input [W_ADDR-1:0]      branch_target  
,   input                   E_Branch       
,   input                   E_Jump          
);
    // ================================================================
    // LOCAL PARAMETERS
    // ================================================================
    localparam INDEX_BITS = 3;                          // 8 sets
    localparam TAG_BITS   = W_ADDR - 2 - INDEX_BITS;    // Remaining bits for tag

    // ================================================================
    // ADDRESS DECODE
    // ================================================================
    // Fetch stage lookup
    wire [INDEX_BITS-1:0] f_index   = F_PC[4:2];
    wire [TAG_BITS-1:0]   f_tag     = F_PC[W_ADDR-1:5];

    // Execute stage update
    wire [INDEX_BITS-1:0] e_index   = E_PC[4:2];
    wire [TAG_BITS-1:0]   e_tag     = E_PC[W_ADDR-1:5];
    wire update_en                  = E_Branch | E_Jump;

    // ================================================================
    // MEMORY ARRAYS - 4 ways x 8 sets
    // ================================================================
    reg [W_ADDR-1:0]    data_mem0 [0:7];    // Target addresses
    reg [W_ADDR-1:0]    data_mem1 [0:7]; 
    reg [W_ADDR-1:0]    data_mem2 [0:7]; 
    reg [W_ADDR-1:0]    data_mem3 [0:7]; 

    reg [TAG_BITS-1:0]  tag_mem0  [0:7];    // Tags
    reg [TAG_BITS-1:0]  tag_mem1  [0:7];
    reg [TAG_BITS-1:0]  tag_mem2  [0:7];
    reg [TAG_BITS-1:0]  tag_mem3  [0:7];

    reg                 valid0    [0:7];    // Valid bits
    reg                 valid1    [0:7];
    reg                 valid2    [0:7];
    reg                 valid3    [0:7];

    wire [3:0] read_hit_ways;       // One-hot read hit
    wire [3:0] write_hit_ways;      // One-hot write hit
    wire [3:0] plru_victim_way;     // Replacement victim
    wire [3:0] final_target_way;    // Way to update 


    // ================================================================
    // READ LOGIC - Check hit in fetch stage
    // ================================================================
    assign read_hit_ways[0] = (tag_mem0[f_index] == f_tag) && valid0[f_index];
    assign read_hit_ways[1] = (tag_mem1[f_index] == f_tag) && valid1[f_index];
    assign read_hit_ways[2] = (tag_mem2[f_index] == f_tag) && valid2[f_index];
    assign read_hit_ways[3] = (tag_mem3[f_index] == f_tag) && valid3[f_index];
    assign hit              = |read_hit_ways;


    // ================================================================
    // READ DATA MUX - Select target from hitting way
    // ================================================================
    always @(*) begin
        case(read_hit_ways)
            4'b0001: pc_prediction = data_mem0[f_index];
            4'b0010: pc_prediction = data_mem1[f_index];
            4'b0100: pc_prediction = data_mem2[f_index];
            4'b1000: pc_prediction = data_mem3[f_index];
            default: pc_prediction = 32'd0;
        endcase
    end
    

    // ================================================================
    // WRITE LOGIC - Update on branch/jump in EX stage
    // ================================================================
    // Check if entry already exists (update in place vs allocate new)
    assign write_hit_ways[0]    = (tag_mem0[e_index] == e_tag) && valid0[e_index];
    assign write_hit_ways[1]    = (tag_mem1[e_index] == e_tag) && valid1[e_index];
    assign write_hit_ways[2]    = (tag_mem2[e_index] == e_tag) && valid2[e_index];
    assign write_hit_ways[3]    = (tag_mem3[e_index] == e_tag) && valid3[e_index];
    
    wire write_hit_any          = |write_hit_ways;
    // If hit: update existing entry; else: use PLRU victim
    assign final_target_way     = write_hit_any ? write_hit_ways : plru_victim_way;

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (k = 0; k < 8; k = k + 1) begin
                valid0[k]       <= 1'b0; 
                valid1[k]       <= 1'b0; 
                valid2[k]       <= 1'b0; 
                valid3[k]       <= 1'b0;

                tag_mem0[k]     <= {(TAG_BITS){1'b0}};
                tag_mem1[k]     <= {(TAG_BITS){1'b0}};
                tag_mem2[k]     <= {(TAG_BITS){1'b0}};
                tag_mem3[k]     <= {(TAG_BITS){1'b0}};

                data_mem0[k]    <= {(W_ADDR){1'b0}};
                data_mem1[k]    <= {(W_ADDR){1'b0}};
                data_mem2[k]    <= {(W_ADDR){1'b0}};
                data_mem3[k]    <= {(W_ADDR){1'b0}};
            end
        end
        else if (update_en) begin
            if (final_target_way[0]) begin
                tag_mem0    [e_index]   <= e_tag;
                data_mem0   [e_index]   <= branch_target;
                valid0      [e_index]   <= 1'b1;
            end
            if (final_target_way[1]) begin
                tag_mem1    [e_index]   <= e_tag;
                data_mem1   [e_index]   <= branch_target;
                valid1      [e_index]   <= 1'b1;
            end
            if (final_target_way[2]) begin
                tag_mem2    [e_index]   <= e_tag;
                data_mem2   [e_index]   <= branch_target;
                valid2      [e_index]   <= 1'b1;
            end
            if (final_target_way[3]) begin
                tag_mem3    [e_index]   <= e_tag;
                data_mem3   [e_index]   <= branch_target;
                valid3      [e_index]   <= 1'b1;
            end
        end
    end

    // ================================================================
    // PLRU REPLACEMENT - ASYNCHRONOUS (Chỉ dùng riêng cho BTB)
    // ================================================================
    
    reg [3:1]   btb_plru_mem [0:7];
    wire [3:1]  current_tree = btb_plru_mem[e_index];
    wire [3:1]  next_tree;

    // 1. Mạch tính toán Victim Way ngay lập tức (Combinational)
    wire [2:0] node_id_1    = current_tree[1] ? 3'd3 : 3'd2;
    wire [1:0] victim_bin   = current_tree[node_id_1] ? {node_id_1[0], 1'b1} : {node_id_1[0], 1'b0};
    assign plru_victim_way  = 4'b0001 << victim_bin;

    // 2. Tính trạng thái cây PLRU tiếp theo (Combinational)
    plru plru_update1 (
        .prev_bit   (current_tree[1])
    ,   .left_hit   (|final_target_way[1:0])
    ,   .right_hit  (|final_target_way[3:2])
    ,   .plru_bit   (next_tree[1])
    );
    
    plru plru_update2 (
        .prev_bit   (current_tree[2])
    ,   .left_hit   (final_target_way[0])
    ,   .right_hit  (final_target_way[1])
    ,   .plru_bit   (next_tree[2])
    );
    
    plru plru_update3 (
        .prev_bit   (current_tree[3])
    ,   .left_hit   (final_target_way[2])
    ,   .right_hit  (final_target_way[3])
    ,   .plru_bit   (next_tree[3])
    );

    // 3. Ghi lại trạng thái mới
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                btb_plru_mem[i] <= 3'd0;
            end
        end 
        else if (update_en) begin
            btb_plru_mem[e_index] <= next_tree;
        end
    end
endmodule