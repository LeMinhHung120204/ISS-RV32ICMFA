`timescale 1ns/1ps
// from Lee Min Hunz with luv
// ============================================================================
// L2 Cache v2 - Unified L2 Cache with ACE Interface
// ============================================================================
//
// Unified L2 cache serving both ICache and DCache.
// Implements MOESI coherence via ACE interface.
//
// Features:
//   - N-way set associative (default 4-way)
//   - 64-byte cache line (16 words)
//   - MOESI coherence protocol states
//   - ACE master interface to interconnect
//   - Snoop forwarding to L1 caches
//   - PLRU replacement
//
// Request Commands (i_req_cmd):
//   00 = Read_Shared   : Read for shared access (may hit in peer)
//   01 = Write_Back    : Evict dirty line to memory
//   10 = Upgrade       : Upgrade S->E/M (invalidate peers)
//   11 = Read_Unique   : Read for exclusive access
//
// Interfaces:
//   L1 Interface:
//     - Request: cmd + address from L1 cache
//     - Write: Dirty line from L1 writeback
//     - Read: Cache line for L1 refill
//     - Snoop: Forward external snoops to L1
//
//   ACE Interface (to Interconnect):
//     - AXI4 AW/W/B (write), AR/R (read) channels
//     - ACE AC/CR/CD channels for snoop protocol
//
// ============================================================================
module L2_cache_v2 #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 32,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  
    parameter BYTE_OFF_W    = 2,
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32, // 512 bits
    parameter CORE_ID       = 1'b0,    

    parameter ID_W          = 2,
    parameter STRB_W        = (DATA_W/8)
)(
    input ACLK
,   input ARESETn

    // Request (Command/Address)
,   input                       i_req_valid  
,   input   [1:0]               i_req_cmd    // 00: Read_Shared, 01: Write_Back, 10: UPGRADE/INVALIDATE, 11: Read_Unique
,   input   [ADDR_W-1:0]        i_L1_read_addr
,   input   [ADDR_W-1:0]        i_req_addr   
,   output                      o_req_ready  
,   output  [11:0]              o_L1_moesi_state

    // Write Data (Data from L1 writeback)
,   input  [CACHE_DATA_W-1:0]   i_wdata     
,   input                       i_wdata_valid
,   output                      o_wdata_ready

    // Read Data (Data to L1 refill)
,   output [CACHE_DATA_W-1:0]   o_rdata      
,   output                      o_rdata_valid
,   input                       i_rdata_ready

    // Snoop Internal (Forwarding -> L1)
,   output                      o_int_snoop_valid
,   output [ADDR_W-1:0]         o_int_snoop_addr
,   output                      snoop_req_invalidate

,   input                       i_int_snoop_hit
,   input                       i_l1_snoop_complete
,   input                       i_int_snoop_dirty
,   input  [CACHE_DATA_W-1:0]   i_int_snoop_data

    // (cache L2 <-> cache L3)
    // AW channel 
,   input                       iAWREADY
,   output  [ID_W-1:0]          oAWID
,   output  [ADDR_W-1:0]        oAWADDR
,   output  [7:0]               oAWLEN
,   output  [2:0]               oAWSIZE
,   output  [1:0]               oAWBURST
,   output                      oAWVALID
    // tin hieu them
,   output  [2:0]               oAWSNOOP
,   output  [1:0]               oAWDOMAIN
    
    // W channel
,   input                           iWREADY
,   output reg  [DATA_W-1:0]        oWDATA
,   output  [STRB_W-1:0]            oWSTRB
,   output                          oWLAST
,   output                          oWVALID
    
    // B channel
,   input   [ID_W-1:0]          iBID
,   input   [1:0]               iBRESP
,   input                       iBVALID
,   output                      oBREADY

    // AR channel
,   input                       iARREADY
,   output  [ID_W-1:0]          oARID
,   output  [ADDR_W-1:0]        oARADDR
,   output  [7:0]               oARLEN
,   output  [2:0]               oARSIZE
,   output  [1:0]               oARBURST
,   output                      oARVALID
    // tin hieu them
,   output  [3:0]               oARSNOOP
,   output  [1:0]               oARDOMAIN

    // R channel
,   input   [ID_W-1:0]          iRID
,   input   [DATA_W-1:0]        iRDATA
    //  RRESP[3:2] (interconnect)
    //  RRESP[1:0] (memory)
,   input   [3:0]               iRRESP
,   input                       iRLAST
,   input                       iRVALID
,   output                      oRREADY

    // Snoop channel
    // AC channel
,   input                       iACVALID
,   input   [ADDR_W-1:0]        iACADDR
,   input   [3:0]               iACSNOOP
,   output                      oACREADY

    // CR channel
,   input                       iCRREADY
,   output                      oCRVALID
,   output  [4:0]               oCRRESP
    
    // CD channel
,   input                       iCDREADY
,   output                      oCDVALID
,   output reg  [DATA_W-1:0]    oCDDATA
,   output                      oCDLAST
);

    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    // MOESI State Selection
    reg [2:0]               moesi_selected_state;
    
    // Data Buffers
    reg [CACHE_DATA_W-1:0]  refill_buffer;      // Buffer for memory refill data
    reg [CACHE_DATA_W-1:0]  snoop_buffer;       // Buffer for snoop response data
    reg [CACHE_DATA_W-1:0]  line_select;        // Selected cache line output

    // ================================================================
    // WIRE DECLARATIONS
    // ================================================================
    // Stage 1 Address Decode (Cycle 1: Access)
    wire [TAG_W-1:0]        s1_tag, s1_ac_tag;
    wire [INDEX_W-1:0]      s1_index, s1_ac_index;
    wire [WORD_OFF_W-1:0]   s1_word_off;
    wire [BYTE_OFF_W-1:0]   s1_byte_off;

    // Stage 2 Pipeline Signals (Cycle 2: Compare)
    wire                    s2_req;
    wire [TAG_W-1:0]        s2_tag, s2_snoop_tag;
    wire [INDEX_W-1:0]      s2_index, s2_snoop_index;
    wire [WORD_OFF_W-1:0]   s2_word_off;
    wire [BYTE_OFF_W-1:0]   s2_byte_off;
    wire [1:0]              s2_cmd;
    wire                    s2_is_snoop;

    // Control Signals
    wire                    snoop_busy;
    wire                    snoop_hit;
    wire                    snoop_can_access_ram;
    wire                    reg_snoop_stall;
    wire                    stall_contoller;
    wire                    bus_rw;

    // Memory Arrays Output
    wire [TAG_W-1:0]        tag_read    [0:NUM_WAYS-1];
    wire [CACHE_DATA_W-1:0] data_read   [0:NUM_WAYS-1];
    
    // MOESI & Hit Logic
    wire [3:0]              way_hit;
    wire [3:0]              way_select;
    wire [3:0]              way_select_final;
    wire [3:0]              choosen_way;
    wire                    any_hit;
    wire [2:0]              moesi_current_state     [0:NUM_WAYS-1];
    wire [2:0]              L1_moesi_current_state  [0:NUM_WAYS-1];
    wire [2:0]              moesi_next_state;
    wire                    bus_snoop_valid;
    wire                    moesi_we, snoop_moesi_we, main_moesi_we;
    wire                    is_unique, is_dirty, is_owner, is_valid;
    
    // Controller Output Signals
    wire                    tag_we;
    wire                    refill_we;
    wire                    o_rdata_ready_ctrl;
    wire [3:0]              burst_cnt;
    wire [3:0]              burst_cnt_snoop;
    wire                    use_l1_data_mux;
    wire                    is_shared_response;
    wire                    is_dirty_response;

    // Address Muxing
    wire [ADDR_W-1:0]       s1_mux_addr;
    wire [INDEX_W-1:0]      lq_req_moesi_index;
    wire [TAG_W-1:0]        tag_select;

    // ================================================================
    // DERIVED SIGNALS
    // ================================================================
    assign s1_mux_addr      = (iACVALID) ? iACADDR : i_req_addr;
    assign choosen_way      = (any_hit) ? way_hit : way_select;
    assign moesi_we         = main_moesi_we | snoop_moesi_we;
    assign tag_select       = (s2_is_snoop) ? s2_snoop_tag : s2_tag;
    assign way_select_final = (any_hit) ? way_hit : way_select;
    assign o_L1_moesi_state = {L1_moesi_current_state[3], L1_moesi_current_state[2], 
                               L1_moesi_current_state[1], L1_moesi_current_state[0]};
    assign o_rdata          = line_select;
    assign o_rdata_valid    = o_rdata_ready_ctrl;

    // ================================================================
    // STAGE 1: ACCESS
    // ================================================================
    access #(
        .ADDR_W     (ADDR_W),
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS)
    ) access_inst (
        .cpu_addr               (s1_mux_addr),
        .dcache_req_moesi_addr  (i_L1_read_addr),
        .ac_addr                (iACADDR),

        .cpu_tag                (s1_tag),            
        .ac_tag                 (s1_ac_tag),
        .cpu_index              (s1_index), 
        .ac_index               (s1_ac_index),  
        .cpu_word_off           (s1_word_off),
        .cpu_byte_off           (s1_byte_off),
        .dcache_req_moesi_index (lq_req_moesi_index)
    );

    // ================================================================
    // SRAM ARRAYS
    // ================================================================
    // --- Tag RAMs ---
    genvar i;
    generate
        for (i = 0; i < NUM_WAYS; i = i + 1) begin : tag_rams
            tag_mem #( 
                .NUM_SETS(NUM_SETS), 
                .TAG_W(TAG_W) 
            ) u_tag_mem (
                .clk                    (ACLK), 
                .rst_n                  (ARESETn),

                .L1_read_index          (lq_req_moesi_index),
                .L1_moesi_current_state (L1_moesi_current_state[i]),

                .tag_we                 (tag_we & way_select[i]),
                .moesi_we               (moesi_we & choosen_way[i]),
                // .read_index             (read_index_src ? s1_index : s2_index),   
                .read_index             (s1_index),   
                .write_index            (s2_index),           
                .din_tag                (s2_tag),            
                .dout_tag               (tag_read[i]),
                .moesi_next_state       (moesi_next_state),
                .moesi_current_state    (moesi_current_state[i])
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
                // .read_index     (read_index_src ? s1_index : s2_index),  
                .read_index     (s1_index),  
                .dout           (data_read[i]),
                
                // Ghi nguyen dong cache
                .refill_we      (refill_we & way_select[i]),
                .write_index    (s2_index),
                .refill_din     (refill_buffer),
                
                // Ghi tung word (hien tai ko dung o L2)
                .cpu_din        (32'd0), 
                .cpu_we         (1'b0), 
                .cpu_wstrb      (4'b0),           
                .cpu_offset     (4'b0)
            );
        end
    endgenerate

    // ================================================================
    // PIPELINE REGISTER
    // ================================================================
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
        // .s1_req         (i_req_valid | iACVALID),
        .s1_req         (i_req_valid),    
        // .s1_we          (internal_we),   
        .s1_cmd         (i_req_cmd),   
        // .s1_size        (2'b10),
        .s1_wdata       ({DATA_W{1'b0}}),
        .s1_tag         (s1_tag),    
        .s1_index       (s1_index),   
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),

        .snoop_stall    (reg_snoop_stall),
        .s1_is_snoop    (iACVALID),
        .s1_snoop_tag   (s1_ac_tag),
        .s1_snoop_index (s1_ac_index),

        // Stage 2 Outputs
        .s2_req         (s2_req),
        // .s2_we          (s2_we),
        .s2_cmd         (s2_cmd),
        // .s2_size        (s2_size),
        // .s2_wdata       (s2_wdata),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off),

        .s2_is_snoop    (s2_is_snoop),
        .s2_snoop_tag   (s2_snoop_tag),
        .s2_snoop_index (s2_snoop_index)
    );

    // ================================================================
    // STAGE 2: HIT LOGIC
    // ================================================================
    assign way_hit[0] = (tag_read[0] == tag_select) & (moesi_current_state[0] != 3'd4);
    assign way_hit[1] = (tag_read[1] == tag_select) & (moesi_current_state[1] != 3'd4);
    assign way_hit[2] = (tag_read[2] == tag_select) & (moesi_current_state[2] != 3'd4);
    assign way_hit[3] = (tag_read[3] == tag_select) & (moesi_current_state[3] != 3'd4);

    assign snoop_hit = |way_hit & s2_is_snoop;
    assign any_hit   = |way_hit;
    
    always @(*) begin
        case (way_select_final)
            4'b0001: moesi_selected_state = moesi_current_state[0];
            4'b0010: moesi_selected_state = moesi_current_state[1];
            4'b0100: moesi_selected_state = moesi_current_state[2];
            4'b1000: moesi_selected_state = moesi_current_state[3];
            default: moesi_selected_state = 3'd4; 
        endcase
    end

    // ================================================================
    // OUTPUT DATA LOGIC (L2 -> L1)
    // ================================================================
    
    always @(*) begin
        case(way_hit)
            4'b0001: line_select = data_read[0];
            4'b0010: line_select = data_read[1];
            4'b0100: line_select = data_read[2];
            4'b1000: line_select = data_read[3];
            default: line_select = {CACHE_DATA_W{1'b0}};
        endcase
    end

    // ================================================================
    // REFILL & SNOOP BUFFER LOGIC
    // ================================================================
    // Refill Buffer: Receive data from Memory (AXI R) or L1 (Writeback)
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            refill_buffer <= {CACHE_DATA_W{1'b0}};
        end 
        else begin 
            // Case 1: Refill from Memory (AXI R Channel)
            if (iRVALID & oRREADY & (iRID == CORE_ID)) begin
                refill_buffer[burst_cnt * DATA_W +: DATA_W] <= iRDATA;
            end 

            // Case 2: Writeback from L1 (L1 Interface)
            else if (i_wdata_valid && o_wdata_ready) begin
                refill_buffer <= i_wdata;
            end
        end 
    end

    // Snoop Buffer: Capture forwarding data from L1
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            snoop_buffer <= {CACHE_DATA_W{1'b0}};
        end 
        else begin 
            if (i_int_snoop_hit & i_l1_snoop_complete) begin
                snoop_buffer <= i_int_snoop_data;
            end
        end 
    end

    // ================================================================
    // REPLACEMENT POLICY
    // ================================================================
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

    // ================================================================
    // MAIN CONTROLLER
    // ================================================================
    cache_L2_controller_v2 #(
        .DATA_W         (DATA_W), 
        .ADDR_W         (ADDR_W)
    ) u_controller (
        .clk        (ACLK), 
        .rst_n      (ARESETn),

        // Inputs
        .snoop_busy             (snoop_busy),
        .snoop_hit              (snoop_hit),
        .snoop_req_invalidate   (snoop_req_invalidate),
        .snoop_can_access_ram   (snoop_can_access_ram),
        
        .i_req_valid            (s2_req), 
        .i_req_cmd              (s2_cmd),
        
        .hit                    (any_hit),
        .victim_dirty           (is_dirty),      
        .is_valid               (is_valid),
        .current_moesi_state    (moesi_selected_state),
        
        // Data Path Handshake
        .i_wdata_valid      (i_wdata_valid), // Input tu L1
        .o_wdata_ready      (o_wdata_ready),

        .o_rdata_ready      (o_rdata_ready_ctrl),

        // Outputs to Datapath
        .tag_we             (tag_we),
        .moesi_we           (main_moesi_we),
        .refill_we          (refill_we),
        // .read_index_src     (read_index_src),
        .stall              (stall_contoller),
        .is_shared_response (is_shared_response),
        .is_dirty_response  (is_dirty_response),
        .o_req_ready        (o_req_ready),
        .burst_cnt          (burst_cnt),

        // AXI Interface
        .oAWLEN     (oAWLEN), 
        .oAWSIZE    (oAWSIZE), 
        .oAWBURST   (oAWBURST), 
        .oAWVALID   (oAWVALID), 
        .iAWREADY   (iAWREADY),
        .oAWSNOOP   (oAWSNOOP), 
        .oAWDOMAIN  (oAWDOMAIN),

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
        .oARSNOOP   (oARSNOOP), 
        .oARDOMAIN  (oARDOMAIN),

        // .iRID       (iRID), 
        .iRRESP     (iRRESP), 
        .iRLAST     (iRLAST), 
        .iRVALID    (iRVALID), 
        .oRREADY    (oRREADY)
    );

    // ID Assignments
    assign oAWID    = {1'b0, CORE_ID};
    assign oARID    = {1'b0, CORE_ID};
    assign oAWADDR  = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign oARADDR  = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};

    // ================================================================
    // SNOOP FORWARDING & MOESI CONTROLLER
    // ================================================================    
    // Forwarding Address to L1
    assign o_int_snoop_addr     = {s2_snoop_tag, s2_snoop_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};

    // 2. Snoop Controller
    snoop_controller_v2 #( 
        .ADDR_W(ADDR_W) 
    ) u_snoop_ctrl (
        .clk                    (ACLK), 
        .rst_n                  (ARESETn),
        
        // thong tin tu L2
        .snoop_hit              (snoop_hit),
        .is_unique              (is_unique), 
        .is_dirty               (is_dirty), 
        .is_owner               (is_owner),
        .snoop_can_access_ram   (snoop_can_access_ram),
        .reg_snoop_stall        (reg_snoop_stall),

        // Thong tin tu L1
        .i_l1_snoop_complete    (i_l1_snoop_complete),
        .i_l1_is_dirty          (i_int_snoop_dirty),
        .snoop_req_invalidate   (snoop_req_invalidate),
        .i_l1_has_data          (i_int_snoop_hit), // Hit o L1 coi nhu L1 co data

        // Output dieu khien L1
        .l1_forward_valid       (o_int_snoop_valid),
        
        // Output dieu khien L2
        .moesi_we               (snoop_moesi_we),
        .snoop_busy             (snoop_busy),
        .bus_rw                 (bus_rw),
        .bus_snoop_valid        (bus_snoop_valid),
        .use_l1_data_mux        (use_l1_data_mux),
        .burst_cnt_snoop        (burst_cnt_snoop),

        // AXI Snoop Channels
        .ACVALID    (iACVALID), 
        .ACSNOOP    (iACSNOOP), 
        // .ACPROT     (3'b000), 
        .ACREADY    (oACREADY),

        .CRREADY    (iCRREADY), 
        .CRVALID    (oCRVALID), 
        .CRRESP     (oCRRESP),

        .CDREADY    (iCDREADY), 
        .CDLAST     (oCDLAST),  
        .CDVALID    (oCDVALID)
    );

    moesi_controller u_moesi_ctrl (
        .current_state      (moesi_selected_state),
        
        .is_shared_response (is_shared_response),
        .is_dirty_response  (is_dirty_response),
        .refill_we          (refill_we),

        // Request L1 gui xuong
        .cpu_req_valid      (s2_req),   
        .cpu_hit            (any_hit), 
        .cpu_rw             (s2_cmd[0]), 
        .l1_dirty           (i_int_snoop_dirty),

        .bus_snoop_valid    (bus_snoop_valid),
        .snoop_hit          (snoop_hit),
        .bus_rw             (bus_rw),          // 1=Invalidate, 0=Downgrade/Share

        // Outputs (Trang thai logic)
        .is_dirty           (is_dirty),
        .is_unique          (is_unique),
        .is_owner           (is_owner),
        .is_valid           (is_valid),

        .next_state         (moesi_next_state)
    );
    // ================================================================
    // MUX WRITE DATA
    // ================================================================ 
    // Mux Write Data for Bus (Evict/Snoop Response)
    always @(*) begin
        // select 32-bit word out of 512-bit line based on burst_cnt
        case(way_select_final)
            4'b0001: oWDATA = data_read[0][burst_cnt*DATA_W +: DATA_W];
            4'b0010: oWDATA = data_read[1][burst_cnt*DATA_W +: DATA_W];
            4'b0100: oWDATA = data_read[2][burst_cnt*DATA_W +: DATA_W];
            4'b1000: oWDATA = data_read[3][burst_cnt*DATA_W +: DATA_W];
            default: oWDATA = {DATA_W{1'b0}};
        endcase
    end
    
    // Mux CD Data (Snoop Response Data)
    always @(*) begin
        if (use_l1_data_mux) begin
            // Neu Snoop Controller bao lay tu L1 (vi L1 co ban Dirty moi hon)
            oCDDATA = i_int_snoop_data[burst_cnt_snoop*DATA_W +: DATA_W];
        end
        else begin
            case(way_hit)
                4'b0001: oCDDATA = data_read[0][burst_cnt_snoop*DATA_W +: DATA_W];
                4'b0010: oCDDATA = data_read[1][burst_cnt_snoop*DATA_W +: DATA_W];
                4'b0100: oCDDATA = data_read[2][burst_cnt_snoop*DATA_W +: DATA_W];
                4'b1000: oCDDATA = data_read[3][burst_cnt_snoop*DATA_W +: DATA_W];
                default: oCDDATA = {CACHE_DATA_W{1'b0}};
            endcase
        end 
    end

endmodule