`timescale 1ns / 1ps
// Branch Target Buffer
// 4-way set associative, 8 sets
// PLRU replacement policy
// From Lee Min Hunz with love
module BTB #(
    parameter W_ADDR = 32
)(
    input                   clk, rst_n,
    input [W_ADDR-1:0]      F_PC,
    output reg [W_ADDR-1:0] pc_prediction,
    output                  hit,

    input [W_ADDR-1:0]      E_PC,           
    input [W_ADDR-1:0]      branch_target,  
    input                   E_Branch,       
    input                   E_Jump          
);
    localparam INDEX_BITS = 3;            
    localparam TAG_BITS   = W_ADDR - 2 - INDEX_BITS;

    wire [INDEX_BITS-1:0] f_index   = F_PC[4:2];
    wire [TAG_BITS-1:0]   f_tag     = F_PC[W_ADDR-1:5];

    wire [INDEX_BITS-1:0] e_index   = E_PC[4:2];
    wire [TAG_BITS-1:0]   e_tag     = E_PC[W_ADDR-1:5];
    
    wire update_en                  = E_Branch | E_Jump;

    reg [W_ADDR-1:0]    data_mem0 [0:7]; 
    reg [W_ADDR-1:0]    data_mem1 [0:7]; 
    reg [W_ADDR-1:0]    data_mem2 [0:7]; 
    reg [W_ADDR-1:0]    data_mem3 [0:7]; 

    reg [TAG_BITS-1:0]  tag_mem0  [0:7];
    reg [TAG_BITS-1:0]  tag_mem1  [0:7];
    reg [TAG_BITS-1:0]  tag_mem2  [0:7];
    reg [TAG_BITS-1:0]  tag_mem3  [0:7];

    reg                 valid0    [0:7];
    reg                 valid1    [0:7];
    reg                 valid2    [0:7];
    reg                 valid3    [0:7];

    wire [3:0] read_hit_ways;
    wire [3:0] write_hit_ways;
    wire [3:0] plru_victim_way; 
    wire [3:0] final_target_way; 


    // ------------------------------ check read hit ------------------------------
    assign read_hit_ways[0] = (tag_mem0[f_index] == f_tag) && valid0[f_index];
    assign read_hit_ways[1] = (tag_mem1[f_index] == f_tag) && valid1[f_index];
    assign read_hit_ways[2] = (tag_mem2[f_index] == f_tag) && valid2[f_index];
    assign read_hit_ways[3] = (tag_mem3[f_index] == f_tag) && valid3[f_index];
    assign hit              = |read_hit_ways;


    // ------------------------------ read data ------------------------------
    always @(*) begin
        case(read_hit_ways)
            4'b0001: pc_prediction = data_mem0[f_index];
            4'b0010: pc_prediction = data_mem1[f_index];
            4'b0100: pc_prediction = data_mem2[f_index];
            4'b1000: pc_prediction = data_mem3[f_index];
            default: pc_prediction = 32'd0;
        endcase
    end
    

    // ------------------------------ check write hit ------------------------------
    assign write_hit_ways[0]    = (tag_mem0[e_index] == e_tag) && valid0[e_index];
    assign write_hit_ways[1]    = (tag_mem1[e_index] == e_tag) && valid1[e_index];
    assign write_hit_ways[2]    = (tag_mem2[e_index] == e_tag) && valid2[e_index];
    assign write_hit_ways[3]    = (tag_mem3[e_index] == e_tag) && valid3[e_index];
    
    wire write_hit_any          = |write_hit_ways;
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

endmodule