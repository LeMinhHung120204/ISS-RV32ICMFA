`timescale 1ns / 1ps
// Branch Target Buffer
// 4-way set associative, 8 sets
// LRU replacement policy
// From Lee Min Hunz with love
module BTB #(
    parameter W_ADDR = 32
)(
    input                   clk, rst_n,
    input [W_ADDR-1:0]      F_PC,
    output reg [W_ADDR-1:0] pc_prediction,
    output                  hit,

    input [W_ADDR-1:0]      E_PC,           // PC lệnh nhảy
    input [W_ADDR-1:0]      branch_target,  // Địa chỉ đích nhảy tới
    input                   E_branch,        // Là lệnh Branch
    input                   E_jump           // Là lệnh Jump
);
    localparam INDEX_BITS = 3;            
    localparam TAG_BITS   = W_ADDR - 2 - INDEX_BITS;

    wire [INDEX_BITS-1:0] f_index = F_PC[4:2];
    wire [TAG_BITS-1:0]   f_tag   = F_PC[W_ADDR-1:5];

    wire [INDEX_BITS-1:0] e_index = E_PC[4:2];
    wire [TAG_BITS-1:0]   e_tag   = E_PC[W_ADDR-1:5];
    
    wire update_en = E_branch | E_jump;

    reg [W_ADDR-1:0]    data_mem [0:3][0:7]; 
    reg [TAG_BITS-1:0]  tag_mem  [0:3][0:7];
    reg                 valid    [0:3][0:7];

    wire [3:0] read_hit_ways;
    
    genvar g;
    generate
        for(g=0; g<4; g=g+1) begin : read_check
            assign read_hit_ways[g] = (tag_mem[g][f_index] == f_tag) && valid[g][f_index];
        end
    endgenerate

    assign hit = |read_hit_ways;

    always @(*) begin
        case(read_hit_ways)
            4'b0001: pc_prediction = data_mem[0][f_index];
            4'b0010: pc_prediction = data_mem[1][f_index];
            4'b0100: pc_prediction = data_mem[2][f_index];
            4'b1000: pc_prediction = data_mem[3][f_index];
            default: pc_prediction = 32'd0;
        endcase
    end
    
    wire [3:0] write_hit_ways;
    generate
        for(g=0; g<4; g=g+1) begin : write_check_logic
            assign write_hit_ways[g] = (tag_mem[g][e_index] == e_tag) && valid[g][e_index];
        end
    endgenerate
    
    wire write_hit_any = |write_hit_ways;

    wire [3:0] plru_victim_way; 
    wire [3:0] final_target_way; 

    assign final_target_way = write_hit_any ? write_hit_ways : plru_victim_way;

    cache_replacement #(
        .N_WAYS(4), 
        .N_LINES(8)
    ) BTB_replacement_policy (
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (update_en),      
        .addr       (e_index),        
        .way_hit    (final_target_way),
        .way_select (plru_victim_way)
    );

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (k=0; k<8; k=k+1) begin
                valid[0][k] <= 0; valid[1][k] <= 0; 
                valid[2][k] <= 0; valid[3][k] <= 0;
            end
        end
        else if (update_en) begin
            if (final_target_way[0]) begin
                tag_mem[0][e_index]  <= e_tag;
                data_mem[0][e_index] <= branch_target;
                valid[0][e_index]    <= 1'b1;
            end
            if (final_target_way[1]) begin
                tag_mem[1][e_index]  <= e_tag;
                data_mem[1][e_index] <= branch_target;
                valid[1][e_index]    <= 1'b1;
            end
            if (final_target_way[2]) begin
                tag_mem[2][e_index]  <= e_tag;
                data_mem[2][e_index] <= branch_target;
                valid[2][e_index]    <= 1'b1;
            end
            if (final_target_way[3]) begin
                tag_mem[3][e_index]  <= e_tag;
                data_mem[3][e_index] <= branch_target;
                valid[3][e_index]    <= 1'b1;
            end
        end
    end

endmodule