`timescale 1ns/1ps
// from Lee Min Hunz with luv
// ============================================================================
// DCache v2 - L1 Data Cache with Atomic & Coherence Support
// ============================================================================
//
// Write-back, write-allocate L1 data cache with MOESI coherence.
// Supports RV32A atomic instructions (LR/SC/AMO).
//
// Features:
//   - N-way set associative (default 4-way)
//   - 64-byte cache line (16 words)
//   - Write-back policy with dirty tracking
//   - PLRU replacement
//   - Atomic operations: LR.W, SC.W, AMO*
//   - Snoop interface for cache coherence
//
// Interfaces:
//   CPU Interface:
//     - cpu_req/we: Read/write request
//     - cpu_lr/sc/amo: Atomic operation signals
//     - data_rdata: Read data to CPU
//     - pipeline_stall: Stall CPU on miss
//
//   L2 Interface:
//     - Request channel: Read/write/upgrade requests
//     - Write data: Writeback dirty lines
//     - Read data: Refill on miss
//     - MOESI state: Coherence state from L2
//
//   Snoop Interface:
//     - Receive snoop from L2 (forwarded from interconnect)
//     - Return hit/dirty status
//     - Invalidate/downgrade on external request
//
// ============================================================================
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
    input clk, rst_n

    // ================= CPU INTERFACE =================
,   input                       cpu_req, cpu_we
,   input   [ADDR_W-1:0]        cpu_addr
,   input   [DATA_W-1:0]        cpu_din
,   input   [1:0]               cpu_size
    
    // Them tin hieu Atomic tu CPU
,   input                       cpu_lr
,   input                       cpu_sc
,   input                       cpu_amo
,   input   [2:0]               cpu_amo_op
,   output                      o_sc_success // Tra ve ket qua SC (0=Success, 1=Fail)

,   output  reg [DATA_W-1:0]    data_rdata
,   output                      pipeline_stall

    // ================= L2 INTERFACE =================
    // Request address
,   output                      o_l2_req_valid
,   input                       i_l2_req_ready
,   output  [1:0]               o_l2_req_cmd 
,   output  [ADDR_W-1:0]        o_l2_req_addr

    // Request Moesi
,   input   [11:0]              i_l2_req_moesi_state
    
    // Write Data (WB)
,   output  reg [CACHE_DATA_W-1:0]  o_l2_wdata
,   output                          o_l2_wdata_valid
,   input                           i_l2_wdata_ready

    // Read Data (Refill)
,   input                       i_l2_rdata_valid
,   input   [CACHE_DATA_W-1:0]  i_l2_rdata
,   output                      o_l2_rdata_ready

    // Snoop Interface
,   input                       i_snoop_valid
,   input   [ADDR_W-1:0]        i_snoop_addr
,   input                       i_snoop_req_invalid
    
,   output                          o_snoop_complete
,   output  reg                     o_snoop_hit
,   output  reg                     o_snoop_dirty
,   output  reg [CACHE_DATA_W-1:0]  o_snoop_data

);

    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    // Pipeline Buffers
    reg [CACHE_DATA_W-1:0]  refill_buffer;
    
    // Data Output & Selection
    reg [DATA_W-1:0]        word_select;
    reg [DATA_W-1:0]        raw_rdata;
    reg                     raw_en;
    
    // MOESI State Selection
    reg [2:0]               moesi_selected_state;

    // Dirty Array (per set, per way)
    reg [NUM_WAYS-1:0]      dirty_array [0:NUM_SETS-1];

    // Victim Tag (for writeback address)
    reg [TAG_W-1:0]         victim_tag;

    // ================================================================
    // WIRE DECLARATIONS
    // ================================================================
    // Stage 1 Address Decode
    wire [TAG_W-1:0]        s1_tag;
    wire [INDEX_W-1:0]      s1_index;
    wire [WORD_OFF_W-1:0]   s1_word_off;
    wire [BYTE_OFF_W-1:0]   s1_byte_off;
    
    // Stage 2 Pipeline Signals
    wire [TAG_W-1:0]        s2_tag;
    wire [INDEX_W-1:0]      s2_index;
    wire [WORD_OFF_W-1:0]   s2_word_off;
    wire [BYTE_OFF_W-1:0]   s2_byte_off;
    wire                    s2_req;
    wire                    s2_we;
    wire [1:0]              s2_size;
    wire [DATA_W-1:0]       s2_wdata;
    wire                    s2_is_snoop;
    
    // Stage 2 Atomic Signals
    wire                    s2_atomic_lr;
    wire                    s2_atomic_sc;
    wire                    s2_atomic_amo;
    wire [2:0]              s2_amo_op;
    wire                    sc_done;

    // AMO ALU
    wire [DATA_W-1:0]       amo_alu_result;

    // Memory Arrays (Tag & Data RAMs)
    wire [TAG_W-1:0]        tag_read    [0:NUM_WAYS-1];
    wire [CACHE_DATA_W-1:0] data_read   [0:NUM_WAYS-1];
    wire [NUM_WAYS-1:0]     current_valid;

    // Controller Signals
    wire                    tag_we, data_we, refill_we;
    wire [NUM_WAYS-1:0]     way_hit;
    wire [NUM_WAYS-1:0]     way_select;
    wire                    cpu_hit;
    wire                    read_index_src;
    wire                    snoop_stall;
    wire                    stall_contoller;

    // Dirty/Valid Status
    wire [NUM_WAYS-1:0]     current_dirty;
    wire                    invalid;
    wire                    victim_dirty_bit;
    wire                    victim_valid_bit;

    // Address Generation
    wire [ADDR_W-1:0]       s1_mux_addr;
    wire [ADDR_W-1:0]       s2_full_addr;
    wire [ADDR_W-1:0]       victim_addr_full;
    wire [ADDR_W-1:0]       refill_addr_full;

    // ================================================================
    // DERIVED SIGNALS
    // ================================================================
    assign s1_mux_addr      = (i_snoop_valid) ? i_snoop_addr : (cpu_addr | DATA_START);
    assign current_dirty    = dirty_array[s2_index];
    assign invalid          = s2_is_snoop && o_snoop_hit && i_snoop_req_invalid;
    assign s2_full_addr     = {s2_tag, s2_index, s2_word_off, s2_byte_off};
    assign victim_dirty_bit = |(current_dirty & way_select);
    assign victim_valid_bit = |(current_valid & way_select);
    assign victim_addr_full = {victim_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign refill_addr_full = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign o_l2_req_addr    = (o_l2_req_cmd[0]) ? victim_addr_full : refill_addr_full;

    // ================================================================
    // STAGE 1: ACCESS & SNOOP MUX
    // ================================================================
    
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

    // ================================================================
    // SNOOP
    // ================================================================
    assign o_snoop_complete = s2_is_snoop;

    // ================================================================
    // SRAM ARRAYS
    // ================================================================
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
                // .read_index     (s1_index),         
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
                // .read_index     (s1_index),
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

    // ================================================================
    // PIPELINE REGISTER
    // ================================================================
    assign pipeline_stall   = stall_contoller | i_snoop_valid;

    // Khi refill thi read index lai index thi ton 1 chu khi
    // assign raw_hazard       = cpu_req & data_we & (s1_index == s2_index);

    // when write hit and after that we read from the same address
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            raw_rdata <= {DATA_W{1'b0}};
            raw_en      <= 1'b0;
        end 
        else begin
            if (s1_index == s2_index && data_we && cpu_hit) begin
                raw_rdata <= s2_wdata;;
                raw_en      <= 1'b1;
            end
            else begin
                raw_rdata <= {DATA_W{1'b0}};
                raw_en      <= 1'b0;
            end
        end
    end
    

    acc_cmp #(
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W), 
        .NUM_SETS   (NUM_SETS)
    ) acc_cmp_inst (
        .clk            (clk), 
        .rst_n          (rst_n),
        .stall          (pipeline_stall),
        .snoop_stall    (snoop_stall),
        .flush          (1'b0),

        // Inputs (Stage 1)
        // .s1_req         (cpu_req | i_snoop_valid),
        .s1_req         (cpu_req),
        .s1_we          (cpu_we),
        .s1_size        (cpu_size),
        .s1_wdata       (cpu_din),
        .s1_tag         (s1_tag),
        .s1_index       (s1_index),
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),
        .s1_is_snoop    (i_snoop_valid), 
        
        // [MOI] Inputs Atomic
        .s1_lr          (cpu_lr),
        .s1_sc          (cpu_sc),
        .s1_amo         (cpu_amo),
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

        // Outputs Atomic
        .s2_lr          (s2_atomic_lr),
        .s2_sc          (s2_atomic_sc),
        .s2_amo         (s2_atomic_amo),
        .s2_amo_op      (s2_amo_op)
    );

    // ================================================================
    // STAGE 2: HIT LOGIC
    // ================================================================
    assign way_hit[0] = (tag_read[0] == s2_tag) & current_valid[0];
    assign way_hit[1] = (tag_read[1] == s2_tag) & current_valid[1];
    assign way_hit[2] = (tag_read[2] == s2_tag) & current_valid[2];
    assign way_hit[3] = (tag_read[3] == s2_tag) & current_valid[3];
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

    // ================================================================
    // CONTROLLER INSTANTIATION
    // ================================================================
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
        
        // Atomic Interface
        .i_atomic_lr        (s2_atomic_lr),
        .i_atomic_sc        (s2_atomic_sc),
        .i_atomic_amo       (s2_atomic_amo),
        .o_sc_success       (o_sc_success),
        .sc_done            (sc_done),

        // Snoop Info
        .i_snoop_invalidate (i_snoop_req_invalid && i_snoop_valid),
        .i_snoop_addr       (i_snoop_addr),
        .snoop_busy         (i_snoop_valid),
        .snoop_stall        (snoop_stall),

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

    // ================================================================
    // L2 MUX & REFILL LOGIC
    // ================================================================
    // Victim Tag Selection
    always @(*) begin
        case(way_select)
            4'b0001: victim_tag = tag_read[0];
            4'b0010: victim_tag = tag_read[1];
            4'b0100: victim_tag = tag_read[2];
            4'b1000: victim_tag = tag_read[3];
            default: victim_tag = {TAG_W{1'b0}};
        endcase
    end

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
            // else if (s2_we && cpu_hit && ~s2_is_snoop) begin 
            else if (data_we) begin
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

    // ================================================================
    // AMO ALU INSTANTIATION
    // ================================================================
    amo_alu #(
        .DATA_WIDTH (DATA_W)
    ) u_amo_alu (
        .i_data_from_mem    (word_select),
        .i_data_from_core   (s2_wdata),
        .i_amo_op           (s2_amo_op),
        .o_amo_alu_result   (amo_alu_result) 
    );

    // ================================================================
    // DATA OUTPUT MUX
    // ================================================================
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
        if (sc_done) begin
            data_rdata = {31'd0, o_sc_success};
        end 
        else if (raw_en) begin
            data_rdata = raw_rdata;
        end 
        else begin
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
    end
endmodule