`timescale 1ns/1ps

module L3_cache #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,  
    parameter NUM_SETS      = 64,
    
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  
    parameter BYTE_OFF_W    = 2,
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32, // 512 bits
    parameter STRB_W        = (CACHE_DATA_W/8),
    parameter ID_W          = 2
)(
    input ACLK, ARESETn,
    // INPUT INTERFACE (Request from Interconnect/Arbiter)
    input                   i_req_valid,  
    input  [1:0]            i_req_cmd,    // 00: Read, 01: Write
    input  [ADDR_W-1:0]     i_req_addr,   
    output                  o_req_ready,  

    // Write Data
    input  [CACHE_DATA_W-1:0] i_wdata,     
    input                     i_wdata_valid,
    output                    o_wdata_ready,

    // Read Data
    output [CACHE_DATA_W-1:0] o_rdata,      
    output                    o_rdata_valid,
    input                     i_rdata_ready,

    // 2. AXI4 MASTER INTERFACE (Cache L3 <-> Mem)    
    // AW Channel
    input                   iAWREADY,
    output [ID_W-1:0]       oAWID,
    output [ADDR_W-1:0]     oAWADDR,
    output [7:0]            oAWLEN,
    output [2:0]            oAWSIZE,
    output [1:0]            oAWBURST,
    output                  oAWVALID,

    // W Channel
    input                       iWREADY,
    output reg [CACHE_DATA_W-1:0] oWDATA,
    output [STRB_W-1:0]         oWSTRB,
    output                      oWLAST,
    output                      oWVALID,
    
    // B Channel
    input  [ID_W-1:0]       iBID,
    input  [1:0]            iBRESP,
    input                   iBVALID,
    output                  oBREADY,

    // AR Channel
    input                   iARREADY,
    output [ID_W-1:0]       oARID,
    output [ADDR_W-1:0]     oARADDR,
    output [7:0]            oARLEN,
    output [2:0]            oARSIZE,
    output [1:0]            oARBURST,
    output                  oARVALID,

    // R Channel
    input  [ID_W-1:0]           iRID,
    input  [CACHE_DATA_W-1:0]   iRDATA, 
    input  [1:0]                iRRESP, 
    input                       iRLAST,
    input                       iRVALID,
    output                      oRREADY
);
    // ---------------------------------------- INTERNAL WIRES ----------------------------------------
    wire [TAG_W-1:0]        s1_tag;
    wire [INDEX_W-1:0]      s1_index;
    wire [WORD_OFF_W-1:0]   s1_word_off;
    wire [BYTE_OFF_W-1:0]   s1_byte_off;

    wire                    s2_req;
    wire                    s2_we;
    wire [TAG_W-1:0]        s2_tag;
    wire [INDEX_W-1:0]      s2_index;
    wire [WORD_OFF_W-1:0]   s2_word_off;
    wire [BYTE_OFF_W-1:0]   s2_byte_off;

    // Memory Arrays
    wire [TAG_W-1:0]        tag_read    [0:NUM_WAYS-1];
    wire [CACHE_DATA_W-1:0] data_read   [0:NUM_WAYS-1];
    
    wire [3:0]  way_hit;
    wire        any_hit;
    
    // Controller Output Signals
    wire                    tag_we;
    wire                    refill_we;
    // wire                    data_we;
    reg  [CACHE_DATA_W-1:0] refill_buffer;
    wire [NUM_WAYS-1:0]     way_select;

    // Controller specific for L3
    wire o_wdata_ready_ctrl; 
    wire o_rdata_ready_ctrl;

   // ---------------------------------------- STAGE 1: ACCESS ----------------------------------------
    access #(
        .ADDR_W     (ADDR_W),
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS)
    ) access_inst (
        .cpu_addr       (i_req_addr),
        .cpu_tag        (s1_tag),            
        .cpu_index      (s1_index),    
        .cpu_word_off   (s1_word_off),
        .cpu_byte_off   (s1_byte_off)
    );

    // ---------------------------------------- METADATA ARRAYS (VALID & DIRTY) -----------------------
    reg [NUM_WAYS-1:0] dirty_array [0:NUM_SETS-1];
    wire [NUM_WAYS-1:0] current_dirty = dirty_array[s2_index];

    integer k;
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            for(k = 0; k < NUM_SETS; k = k + 1) begin
                dirty_array[k] <= {NUM_WAYS{1'b0}};
            end
        end else begin
            if (tag_we) begin 
                if (s2_we) begin 
                    dirty_array[s2_index] <= dirty_array[s2_index] | way_select; // Write -> Dirty
                end 
                else begin      
                    dirty_array[s2_index] <= dirty_array[s2_index] & ~way_select; // Read Refill -> Clean
                end 
            end
        end
    end

    // ---------------------------------------- SRAM ARRAYS ----------------------------------------
    wire [NUM_WAYS-1:0] current_valid;
    wire [3:0] choosen_way = (any_hit) ? way_hit : way_select;
    // --- Tag RAMs ---
    genvar i;
    generate
        for (i = 0; i < NUM_WAYS; i = i + 1) begin : tag_rams
            tag_mem #( 
                .NUM_SETS   (NUM_SETS), 
                .TAG_W      (TAG_W) 
            ) u_tag_mem (
                .clk            (ACLK), 
                .rst_n          (ARESETn),
                .tag_we         (tag_we & way_select[i]),
                .valid_we       (tag_we & way_select[i]),
                .write_index    (s2_index),           
                .din_tag        (s2_tag),     
                .dout_tag       (tag_read[i]),
                .dout_valid     (current_valid[i])
            );
        end
    endgenerate

    // --- Data RAMs ---
    generate
        for (i = 0; i < NUM_WAYS; i = i + 1) begin : data_rams
            data_mem #( 
                .DATA_W     (DATA_W), 
                .NUM_SETS   (NUM_SETS) 
            ) u_data_mem (
                .clk            (ACLK), 
                .rst_n          (ARESETn),
                .read_index     (s1_index),  
                .dout           (data_read[i]),
                
                // Ghi nguyen dong cache
                .refill_we      (refill_we & way_select[i]),
                .write_index    (s2_index),
                .refill_din     (refill_buffer),
                
                // Ghi tung word (hien tai ko dung o L3)
                .cpu_din        (32'd0), 
                .cpu_we         (1'b0), 
                .cpu_wstrb      (4'b0),           
                .cpu_offset     (4'b0)
            );
        end
    endgenerate

    // ---------------------------------------- PIPELINE REGISTER ----------------------------------------
    wire stall_contoller;
    assign pipeline_stall = (s2_req & ~any_hit) | stall_contoller; 
    
    acc_cmp #(
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W), 
        .NUM_SETS   (NUM_SETS)
    ) acc_cmp_inst (
        .clk        (ACLK), 
        .rst_n      (ARESETn),
        .stall      (pipeline_stall),
        .flush      (1'b0),

        // Stage 1 Inputs (Mapped from L1 interface)
        .s1_req         (i_req_valid),    
        .s1_we          (i_req_cmd[0]),      
        .s1_size        (2'b10),
        .s1_wdata       ({DATA_W{1'b0}}),
        .s1_tag         (s1_tag),    
        .s1_index       (s1_index),   
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),
        .s1_is_snoop    (1'b0),

        // Stage 2 Outputs
        .s2_req         (s2_req),
        .s2_we          (s2_we),
        .s2_size        (),
        .s2_wdata       (),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off),
        .s2_is_snoop    ()
    );

   // ---------------------------------------- STAGE 2: HIT LOGIC ----------------------------------------
    assign way_hit[0] = (tag_read[0] == s2_tag) & current_valid[0];
    assign way_hit[1] = (tag_read[1] == s2_tag) & current_valid[1];
    assign way_hit[2] = (tag_read[2] == s2_tag) & current_valid[2];
    assign way_hit[3] = (tag_read[3] == s2_tag) & current_valid[3];
    
    assign any_hit = |way_hit;
    wire [NUM_WAYS-1:0] way_select_final = (any_hit) ? way_hit : way_select;

    // ---------------------------------------- OUTPUT DATA LOGIC ----------------------------------------
    reg [CACHE_DATA_W-1:0] line_select;
    
    always @(*) begin
        case(way_hit)
            4'b0001: line_select = data_read[0];
            4'b0010: line_select = data_read[1];
            4'b0100: line_select = data_read[2];
            4'b1000: line_select = data_read[3];
            default: line_select = {CACHE_DATA_W{1'b0}};
        endcase
    end
    
    assign o_rdata          = line_select;
    assign o_rdata_valid    = o_rdata_ready_ctrl; 

    // ---------------------------------------- REFILL BUFFER LOGIC ----------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            refill_buffer <= {CACHE_DATA_W{1'b0}};
        end 
        else begin 
            // Case 1: Refill from Memory (AXI R Channel)
            if (iRVALID & oRREADY) begin
                refill_buffer <= iRDATA;
            end 
            // Case 2: Writeback from L2
            else if (i_wdata_valid && o_wdata_ready) begin
                refill_buffer <= i_wdata;
            end
        end 
    end 
    
    assign o_wdata_ready = o_wdata_ready_ctrl;

    // ---------------------------------------- REPLACEMENT POLICY ----------------------------------------
    cache_replacement #( 
        .N_WAYS     (NUM_WAYS), 
        .N_LINES    (NUM_SETS) 
    ) u_replacement (
        .clk        (ACLK), 
        .rst_n      (ARESETn),
        .we         (any_hit),
        .way_hit    (way_hit),
        .addr       (s2_index),
        .way_select (way_select)
    );

    // ---------------------------------------- MAIN CONTROLLER ----------------------------------------
    wire victim_dirty_bit = |(current_dirty & way_select);
    wire victim_valid_bit = |(current_valid & way_select);
    
    cache_L2_controller #(
        .DATA_W         (DATA_W), 
        .ADDR_W         (ADDR_W), 
        .CACHE_DATA_W   (CACHE_DATA_W)
    ) u_controller (
        .clk            (ACLK), 
        .rst_n          (ARESETn),
        
        // --- Core Interface ---
        .i_req_valid            (s2_req), 
        .i_req_cmd              (s2_we ? 2'b01 : 2'b00),
        
        .hit                    (any_hit),
        .victim_dirty           (victim_dirty_bit),      
        .is_valid               (victim_valid_bit),
        
        // --- Data Path Handshake ---
        .i_wdata_valid      (i_wdata_valid), 
        .o_wdata_ready      (o_wdata_ready_ctrl),
        .o_rdata_ready      (o_rdata_ready_ctrl),

        // --- Outputs to Datapath ---
        .tag_we             (tag_we),
        .refill_we          (refill_we),
        .stall              (stall_contoller),
        .o_req_ready        (o_req_ready),

        // --- AXI 4 ---
        .oAWLEN     (oAWLEN), 
        .oAWSIZE    (oAWSIZE), 
        .oAWBURST   (oAWBURST), 
        .oAWVALID   (oAWVALID), 
        .iAWREADY   (iAWREADY),

        .oWSTRB     (oWSTRB), 
        .oWLAST     (oWLAST), 
        .oWVALID    (oWVALID), 
        .iWREADY    (iWREADY),

        .iBID       (iBID), 
        .iBRESP     (iBRESP), 
        .iBVALID    (iBVALID), 
        .oBREADY    (oBREADY),

        .oARLEN     (oARLEN), 
        .oARSIZE    (oARSIZE), 
        .oARBURST   (oARBURST), 
        .oARVALID   (oARVALID), 
        .iARREADY   (iARREADY),

        .iRID       (iRID), 
        .iRRESP     ({2'b00, iRRESP}),
        .iRLAST     (iRLAST), 
        .iRVALID    (iRVALID), 
        .oRREADY    (oRREADY)
    );

    assign oAWID    = {ID_W{1'b0}}; // ID = 0
    assign oARID    = {ID_W{1'b0}}; // ID = 0
    assign oAWADDR  = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign oARADDR  = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};

    // ---------------------------------------- Mux Write Data ---------------------------------------- 
    always @(*) begin
        case(way_select_final)
            4'b0001: oWDATA = data_read[0];
            4'b0010: oWDATA = data_read[1];
            4'b0100: oWDATA = data_read[2];
            4'b1000: oWDATA = data_read[3];
            default: oWDATA = {CACHE_DATA_W{1'b0}};
        endcase
    end

endmodule