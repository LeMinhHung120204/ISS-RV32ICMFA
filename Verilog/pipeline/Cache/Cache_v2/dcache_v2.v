`timescale 1ns/1ps
module dcache_v2 #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter DATA_START    = 32'h0000_4000,
    
    // Derived parameters
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4, // 16 words
    parameter BYTE_OFF_W    = 2,
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32
)(
    input clk, rst_n,

    // ================= CPU INTERFACE =================
    input                       cpu_req, cpu_we,
    input   [ADDR_W-1:0]        cpu_addr,
    input   [DATA_W-1:0]        cpu_din,
    
    // [MOI] Them tin hieu Atomic tu CPU
    input                       cpu_atomic_lr,
    input                       cpu_atomic_sc,
    input                       cpu_atomic_amo,
    input   [2:0]               cpu_amo_op,
    output                      o_sc_success, // Tra ve ket qua SC (0=Success, 1=Fail)

    output  reg [DATA_W-1:0]    data_rdata,
    output                      pipeline_stall,
    output                      raw_hazard,

    // ================= L2 INTERFACE =================
    // Request address
    output                      o_l2_req_valid,
    input                       i_l2_req_ready,
    output  [1:0]               o_l2_req_cmd, 
    output  [ADDR_W-1:0]        o_l2_req_addr,

    // Request Moesi
    input   [11:0]              i_l2_req_moesi_state,
    
    // Write Data (WB)
    output  reg [CACHE_DATA_W-1:0]  o_l2_wdata,
    output                          o_l2_wdata_valid,
    input                           i_l2_wdata_ready,

    // Read Data (Refill)
    input                       i_l2_rdata_valid,
    input   [CACHE_DATA_W-1:0]  i_l2_rdata,
    output                      o_l2_rdata_ready,

    // Snoop Interface
    input                       i_snoop_valid,
    input   [ADDR_W-1:0]        i_snoop_addr,
    input                       i_snoop_req_invalid,
    
    output                          o_snoop_complete,
    output  reg                     o_snoop_hit,
    output  reg                     o_snoop_dirty,
    output  reg [CACHE_DATA_W-1:0]  o_snoop_data

);
    // ---------------------------------------- INTERNAL SIGNALS ----------------------------------------
    wire [TAG_W-1:0]        s1_tag, s2_tag;
    wire [INDEX_W-1:0]      s1_index, s2_index;
    wire [WORD_OFF_W-1:0]   s1_word_off, s2_word_off;
    wire [BYTE_OFF_W-1:0]   s1_byte_off, s2_byte_off;
    
    wire                    s2_req;
    wire                    s2_we;
    wire [1:0]              s2_size;
    wire [DATA_W-1:0]       s2_wdata;
    
    wire                    s2_atomic_lr;
    wire                    s2_atomic_sc;
    wire                    s2_atomic_amo;
    wire [2:0]              s2_amo_op;

    wire                    s2_is_snoop;

    // AMO result
    wire [DATA_W-1:0]       amo_alu_result;

    // Arrays & Counters
    wire [TAG_W-1:0]        tag_read    [0:NUM_WAYS-1];
    wire [CACHE_DATA_W-1:0] data_read   [0:NUM_WAYS-1];
    reg  [CACHE_DATA_W-1:0] refill_buffer;

    // Controller signals
    wire                    tag_we, data_we, refill_we;
    wire [NUM_WAYS-1:0]     way_hit;
    wire [NUM_WAYS-1:0]     way_select;
    wire                    cpu_hit;
    wire                    read_index_src;
    wire                    snoop_can_access_ram;
    wire                    stall_contoller;

    // ---------------------------------------- STAGE 1: ACCESS & SNOOP MUX ----------------------------------------
    wire [ADDR_W-1:0] s1_mux_addr   = (i_snoop_valid) ? i_snoop_addr : (cpu_addr | DATA_START);
    
    access #(
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W), 
        .NUM_SETS   (NUM_SETS)
    ) access_inst (
        .cpu_addr       (s1_mux_addr),
        .cpu_tag        (s1_tag),            
        .cpu_index      (s1_index),   
        .cpu_word_off   (s1_word_off),
        .cpu_byte_off   (s1_byte_off)
    );

    // ---------------------------------------- SNOOP ----------------------------------------

    assign o_snoop_complete = s2_is_snoop;
    // ---------------------------------------- SRAM ARRAYS ----------------------------------------
    wire [NUM_WAYS-1:0] current_valid;
    wire invalid;

    assign invalid = s2_is_snoop && o_snoop_hit && i_snoop_req_invalid;
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
                .tag_we         (tag_we & way_select[i]),
                .valid_we       (refill_we & way_select[i]),
                .invalid        (invalid & way_hit[i]),
                .read_index     (read_index_src ? s1_index : s2_index),         
                .write_index    (s2_index),        
                .din_tag        (s2_tag),
                .valid          (current_valid[i]),
                .dout_tag       (tag_read[i])
            );

            // Data RAM
            data_mem #(
                .DATA_W     (DATA_W), 
                .NUM_SETS   (NUM_SETS)
            ) u_data_mem (
                .clk            (clk), 
                .rst_n          (rst_n),
                .read_index     (read_index_src ? s1_index : s2_index),
                .write_index    (s2_index),
                .refill_we      (refill_we & way_select[i]),
                .refill_din     (refill_buffer),
                .cpu_we         (data_we & way_hit[i]),
                .cpu_din        (s2_atomic_amo ? amo_alu_result : s2_wdata),
                .cpu_wstrb      (4'b1111),
                .cpu_offset     (s2_word_off),
                .dout           (data_read[i])
            );
        end
    endgenerate

    // ---------------------------------------- PIPELINE REGISTER ----------------------------------------
    assign pipeline_stall   = (s2_req & ~cpu_hit & ~s2_is_snoop) | stall_contoller | i_snoop_valid;
    assign raw_hazard       = cpu_req & data_we & (s1_index == s2_index);

    acc_cmp #(
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W), 
        .NUM_SETS   (NUM_SETS)
    ) acc_cmp_inst (
        .clk            (clk), 
        .rst_n          (rst_n),
        .stall          (pipeline_stall),
        .snoop_stall    (~snoop_can_access_ram),
        .flush          (1'b0),

        // Inputs (Stage 1)
        .s1_req         (cpu_req | i_snoop_valid),
        .s1_we          (cpu_we),
        .s1_wdata       (cpu_din),
        .s1_tag         (s1_tag),
        .s1_index       (s1_index),
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),
        .s1_is_snoop    (i_snoop_valid), 
        
        // [MOI] Inputs Atomic
        .s1_atomic_lr   (cpu_atomic_lr),
        .s1_atomic_sc   (cpu_atomic_sc),
        .s1_atomic_amo  (cpu_atomic_amo),
        .s1_amo_op      (cpu_amo_op),

        // Outputs (Stage 2)
        .s2_req         (s2_req),
        .s2_we          (s2_we),
        .s2_size        (s2_size),
        .s2_wdata       (s2_wdata),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off),
        .s2_is_snoop    (s2_is_snoop),

        // [MOI] Outputs Atomic
        .s2_atomic_lr   (s2_atomic_lr),
        .s2_atomic_sc   (s2_atomic_sc),
        .s2_atomic_amo  (s2_atomic_amo),
        .s2_amo_op      (s2_amo_op)
    );

    // ---------------------------------------- STAGE 2: HIT LOGIC ----------------------------------------
    reg [NUM_WAYS-1:0]  dirty_array [0:NUM_SETS-1];
    wire [NUM_WAYS-1:0] current_dirty = dirty_array[s2_index];
    
    assign way_hit[0] = (tag_read[0] == s2_tag) & current_valid[0];
    assign way_hit[1] = (tag_read[1] == s2_tag) & current_valid[1];
    assign way_hit[2] = (tag_read[2] == s2_tag) & current_valid[2];
    assign way_hit[3] = (tag_read[3] == s2_tag) & current_valid[3];

    reg [2:0] moesi_selected_state;
    always @(*) begin
        case(way_hit)
            4'b0001: moesi_selected_state = i_l2_req_moesi_state[2:0];
            4'b0010: moesi_selected_state = i_l2_req_moesi_state[5:3];
            4'b0100: moesi_selected_state = i_l2_req_moesi_state[8:6];
            4'b1000: moesi_selected_state = i_l2_req_moesi_state[11:9];
            default: moesi_selected_state = i_l2_req_moesi_state[2:0];
        endcase
    end 

    assign cpu_hit = (|way_hit) & s2_req & ~s2_is_snoop;
    
    // Snoop Output Logic
    always @(*) begin
        if (s2_is_snoop) begin
            o_snoop_hit     = |way_hit;
            o_snoop_dirty   = |(way_hit & current_dirty);
        end 
        else begin
            o_snoop_hit     = 1'b0;
            o_snoop_dirty   = 1'b0;
        end
    end

    always @(*) begin
        case (way_hit)
            4'b0001: o_snoop_data = data_read[0];
            4'b0010: o_snoop_data = data_read[1];
            4'b0100: o_snoop_data = data_read[2];
            4'b1000: o_snoop_data = data_read[3];
            default: o_snoop_data = {DATA_W{1'b0}};
        endcase
    end

    // ---------------------------------------- CONTROLLER INSTANTIATION ----------------------------------------
    wire [ADDR_W-1:0] s2_full_addr = {s2_tag, s2_index, s2_word_off, s2_byte_off};
    wire victim_dirty_bit = |(current_dirty & way_select);
    wire victim_valid_bit = |(current_valid & way_select);

    dcache_controller_v2 u_controller (
        .clk                (clk), 
        .rst_n              (rst_n),
        
        // Cache <-> CPU
        .cpu_req            (s2_req), 
        .cpu_we             (s2_we),
        .cpu_addr           (s2_full_addr),

        // Cache Status
        .hit                (cpu_hit),
        .victim_dirty       (victim_dirty_bit),
        .victim_valid       (victim_valid_bit),
        
        // [MOI] Atomic Interface
        .i_atomic_lr        (s2_atomic_lr),
        .i_atomic_sc        (s2_atomic_sc),
        .i_atomic_amo       (s2_atomic_amo),
        .o_sc_success       (o_sc_success),

        // Snoop Info
        .i_snoop_invalidate (i_snoop_req_invalid && i_snoop_valid),
        .i_snoop_addr       (i_snoop_addr),
        .snoop_busy         (i_snoop_valid),
        .snoop_can_access_ram(snoop_can_access_ram),

        // Outputs Control Signals
        .data_we            (data_we), 
        .tag_we             (tag_we), 
        .refill_we          (refill_we),
        .stall              (stall_contoller),
        .read_index_src     (read_index_src),

        // L2 Interface
        .i_l2_moesi_state   (moesi_selected_state),
        .o_mem_req_valid    (o_l2_req_valid),
        .i_mem_req_ready    (i_l2_req_ready),
        .o_mem_req_cmd      (o_l2_req_cmd),

        .o_mem_wdata_valid  (o_l2_wdata_valid),
        .i_mem_wdata_ready  (i_l2_wdata_ready),

        .i_mem_rdata_valid  (i_l2_rdata_valid),
        .o_mem_rdata_ready  (o_l2_rdata_ready)
    );

    // ---------------------------------------- L2 MUX & REFILL LOGIC ----------------------------------------
    reg [TAG_W-1:0] victim_tag;
    always @(*) begin
        case(way_select)
            4'b0001: victim_tag = tag_read[0];
            4'b0010: victim_tag = tag_read[1];
            4'b0100: victim_tag = tag_read[2];
            4'b1000: victim_tag = tag_read[3];
            default: victim_tag = {TAG_W{1'b0}};
        endcase
    end
    
    wire [ADDR_W-1:0] victim_addr_full = {victim_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    wire [ADDR_W-1:0] refill_addr_full = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};

    assign o_l2_req_addr = (o_l2_req_cmd[0]) ? victim_addr_full : refill_addr_full;

    // Data Mux cho WriteBack
    always @(*) begin
        case(way_select)
            4'b0001: o_l2_wdata = data_read[0];
            4'b0010: o_l2_wdata = data_read[1];
            4'b0100: o_l2_wdata = data_read[2];
            4'b1000: o_l2_wdata = data_read[3];
            default: o_l2_wdata = 32'd0;
        endcase
    end

    // Refill Buffer
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            refill_buffer <= {CACHE_DATA_W{1'b0}};
        end 
        else begin
            if (i_l2_rdata_valid && o_l2_rdata_ready) begin
                refill_buffer <= i_l2_rdata;
            end
        end
    end

    // Dirty Array Logic
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            for(k = 0; k < NUM_SETS; k = k + 1) begin 
                dirty_array[k] <= {NUM_WAYS{1'b0}};
            end
        end 
        else begin
            if (refill_we) begin
                dirty_array[s2_index] <= dirty_array[s2_index] & (~way_select);
            end 
            else if (data_we && cpu_hit && ~s2_is_snoop) begin 
                dirty_array[s2_index] <= dirty_array[s2_index] | way_hit;
            end
        end
    end

    // Cache Replacement
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

    // ---------------------------------------- AMO ALU INSTANTIATION ----------------------------------------
    amo_alu #(
        .DATA_WIDTH (DATA_W)
    ) u_amo_alu (
        .i_data_from_mem    (word_select),
        .i_data_from_core   (s2_wdata),
        .i_amo_op           (s2_amo_op),
        .o_amo_alu_result   (amo_alu_result) 
    );

    // ---------------------------------------- DATA OUTPUT MUX ----------------------------------------
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

    always @(*) begin
        case(s2_size)
            2'b00: data_rdata = word_select; // Word
            2'b01: begin // Byte
                case(s2_byte_off)
                    2'b00: data_rdata = {24'd0, word_select[7:0]};
                    2'b01: data_rdata = {24'd0, word_select[15:8]};
                    2'b10: data_rdata = {24'd0, word_select[23:16]};
                    2'b11: data_rdata = {24'd0, word_select[31:24]};
                endcase
            end 
            2'b10: begin // Half
                case(s2_byte_off[1])
                    1'b0: data_rdata = {16'd0, word_select[15:0]};
                    1'b1: data_rdata = {16'd0, word_select[31:16]};
                endcase
            end
            default: data_rdata = word_select;
        endcase
    end
endmodule