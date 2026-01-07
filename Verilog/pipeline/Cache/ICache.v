`timescale 1ns/1ps
module icache #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter BURST_LEN     = 15,
    
    // Derived parameters
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4, 
    parameter BYTE_OFF_W    = 2,
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32
)(
    input clk, rst_n,

    // cache <-> CPU
    input                       cpu_req,
    input                       icache_flush,
    input   [ADDR_W-1:0]        cpu_addr,
    input                       dcache_stall,
    output  [DATA_W-1:0]        data_rdata,
    output                      pipeline_stall,

    // cache <-> L2
    // Request
    input                       i_l2_req_ready,
    output                      o_l2_req_valid,
    output  [ADDR_W-1:0]        o_l2_req_addr,

    // Read Data (Refill L2 -> icache)
    input                       i_l2_rdata_valid,
    input                       i_l2_rdata_last,
    input   [DATA_W-1:0]        i_l2_rdata,
    output                      o_l2_rdata_ready
);

    // ---------------------------------------- INTERNAL SIGNALS ----------------------------------------
    wire [TAG_W-1:0]        s1_tag, s2_tag;
    wire [INDEX_W-1:0]      s1_index, s2_index;
    wire [WORD_OFF_W-1:0]   s1_word_off, s2_word_off;
    wire [BYTE_OFF_W-1:0]   s1_byte_off, s2_byte_off;
    
    wire                    s2_req;

    // Arrays & Counters
    wire [3:0]              burst_cnt;
    wire [TAG_W-1:0]        tag_read    [0:NUM_WAYS-1];
    wire [CACHE_DATA_W-1:0] data_read   [0:NUM_WAYS-1];
    reg  [CACHE_DATA_W-1:0] refill_buffer;

    // Controller signals
    wire                    tag_we, refill_we;
    wire [NUM_WAYS-1:0]     way_hit;
    wire [NUM_WAYS-1:0]     way_select;
    wire                    cpu_hit;

    // ---------------------------------------- STAGE 1: ACCESS ----------------------------------------
    access #(
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W), 
        .NUM_SETS   (NUM_SETS)
    ) access_inst (
        .cpu_addr       (cpu_addr),
        .cpu_tag        (s1_tag),            
        .cpu_index      (s1_index),   
        .cpu_word_off   (s1_word_off),
        .cpu_byte_off   (s1_byte_off)
    );
    
    // ---------------------------------------- SRAM ARRAYS ----------------------------------------
    genvar i;
    generate
        for (i = 0; i < NUM_WAYS; i = i + 1) begin : rams
            // Tag RAM
            tag_mem #(
                .NUM_SETS   (NUM_SETS), 
                .TAG_W      (TAG_W)
            ) u_tag_mem (
                .clk            (clk), 
                .rst_n          (rst_n),

                // Port read
                .read_index     (s1_index),        
                .dout_tag       (tag_read[i]),

                // Port write
                .tag_we         (tag_we & way_select[i]),                
                .write_index    (s2_index),          
                .din_tag        (s2_tag)  
            );

            // Data RAM (Read Only cho CPU)
            data_mem #(
                .DATA_W     (DATA_W), 
                .NUM_SETS   (NUM_SETS)
            ) u_data_mem (
                .clk            (clk), 
                .rst_n          (rst_n),

                // Port read
                .read_index     (s1_index),
                .dout           (data_read[i]),

                 // refill
                .write_index    (s2_index),
                .refill_we      (refill_we & way_select[i]),
                .refill_din     (refill_buffer),

                // not used
                .cpu_we         (1'b0), 
                .cpu_din        ({DATA_W{1'b0}}),          
                .cpu_wstrb      (4'b0),           
                .cpu_offset     (4'd0)
            );
        end
    endgenerate

    // ---------------------------------------- PIPELINE REGISTER ----------------------------------------
    assign pipeline_stall = s2_req & ~cpu_hit;
    
    acc_cmp #(
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W), 
        .NUM_SETS   (NUM_SETS)
    ) acc_cmp_inst (
        .clk            (clk), 
        .rst_n          (rst_n),
        .stall          (pipeline_stall | dcache_stall),
        .flush          (icache_flush),

        // Inputs
        .s1_req         (cpu_req),
        .s1_we          (1'b0), 
        .s1_size        (2'b00),    
        .s1_wdata       ({DATA_W{1'b0}}), 
        .s1_tag         (s1_tag),
        .s1_index       (s1_index),
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),
    
        // Outputs (Stage 2) 
        .s2_req         (s2_req),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off)
    );

    // ---------------------------------------- STAGE 2: HIT LOGIC ----------------------------------------
    reg [NUM_WAYS-1:0]  valid_array [0:NUM_SETS-1];
    wire [NUM_WAYS-1:0] current_valid = valid_array[s2_index];
    
    assign way_hit[0] = (tag_read[0] == s2_tag) & current_valid[0];
    assign way_hit[1] = (tag_read[1] == s2_tag) & current_valid[1];
    assign way_hit[2] = (tag_read[2] == s2_tag) & current_valid[2];
    assign way_hit[3] = (tag_read[3] == s2_tag) & current_valid[3];

    assign cpu_hit = (|way_hit) & s2_req;

    // ---------------------------------------- L2 INTERFACE ----------------------------------------
    assign o_l2_req_addr = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};

    // ---------------------------------------- LOGIC VALID ARRAY ----------------------------------------
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            for(k = 0; k < NUM_SETS; k = k + 1) begin 
                valid_array[k] <= {NUM_WAYS{1'b0}};
            end 
        end 
        else begin
            if (refill_we) begin 
                valid_array[s2_index] <= valid_array[s2_index] | way_select;
            end 
        end
    end
    
    // Refill Buffer
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin 
            refill_buffer <= {CACHE_DATA_W{1'b0}};
        end 
        else if (i_l2_rdata_valid && o_l2_rdata_ready) begin
             refill_buffer[burst_cnt * DATA_W +: DATA_W] <= i_l2_rdata;
        end
    end

    // ---------------------------------------- CONTROLLER ----------------------------------------
    cache_replacement #( 
        .N_WAYS     (NUM_WAYS), 
        .N_LINES    (NUM_SETS) 
    ) u_replacement (
        .clk        (clk), 
        .rst_n      (rst_n),
        .we         (cpu_hit),
        .way_hit    (way_hit),
        .addr       (s2_index),
        .way_select (way_select)
    );

    icache_controller #(
        .DATA_W     (DATA_W),
        .ADDR_W     (ADDR_W),
        .BURST_LEN  (BURST_LEN)
    ) icache_controller (
        .clk                (clk), 
        .rst_n              (rst_n),
        
        .cpu_req            (s2_req), 
        .hit                (cpu_hit),

        .tag_we             (tag_we), 
        .refill_we          (refill_we),
        .burst_cnt          (burst_cnt),

        .o_mem_req_valid    (o_l2_req_valid),
        .i_mem_req_ready    (i_l2_req_ready),

        .i_mem_rdata_valid  (i_l2_rdata_valid),
        .i_mem_rdata_last   (i_l2_rdata_last),
        .o_mem_rdata_ready  (o_l2_rdata_ready)
    );

    // ---------------------------------------- OUTPUT MUX ----------------------------------------
    reg [DATA_W-1:0] word_select;
    always @(*) begin
        case(way_hit)
            4'b0001: word_select = data_read[0][s2_word_off * DATA_W +: DATA_W];
            4'b0010: word_select = data_read[1][s2_word_off * DATA_W +: DATA_W];
            4'b0100: word_select = data_read[2][s2_word_off * DATA_W +: DATA_W];
            4'b1000: word_select = data_read[3][s2_word_off * DATA_W +: DATA_W];
            default: word_select = 32'd0;
        endcase
    end 
    assign data_rdata = word_select;

endmodule