module d_cache #(
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
    parameter LINE_W        = (1 << WORD_OFF_W) * 32
    parameter ID_W          = 2,
    parameter STRB_W        = (DATA_W/8)
)(
    input clk, rst_n

    // ================= CPU INTERFACE =================
,   input                       cpu_req
,   input                       cpu_we
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

    // ================= Snoop Interface =================
    // REQUEST CHANNEL (D-Cache request Snoop)
,   output                  o_req_valid
,   input                   i_req_ready
,   output [ADDR_W-1:0]     o_req_addr
    // (00=Read Miss, 01=Write Miss, 10=Upgrade/Invalidate Others, 11=Writeback)
,   output [1:0]            o_req_cmd    
,   output [LINE_W-1:0]     o_req_data  // writeback data
    
    // SNOOP RESPONSE DCACHE
,   input                   i_resp_valid
,   output                  o_resp_ready
,   input  [LINE_W-1:0]     i_resp_data

    // SNOOP REQUEST DCACHE
,   input                   i_snp_req_valid
,   output                  o_snp_req_ready
,   input  [ADDR_W-1:0]     i_snp_req_addr
,   input  [1:0]            i_snp_req_cmd

    // DCACHE RESPONSE SNOOP
,   output                  o_snp_resp_valid
,   input                   i_snp_resp_ready
,   output                  o_snp_resp_hit      
,   output [LINE_W-1:0]     o_snp_resp_data
,   output                  snoop_req_invalidate
);

    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    // MOESI State Selection
    reg [2:0]               moesi_selected_state;
    
    // Data Buffers
    reg [LINE_W-1:0]  refill_buffer;      // Buffer for memory refill data

    // Data Output & Selection
    reg [DATA_W-1:0]        word_select;
    reg [DATA_W-1:0]        raw_rdata;
    reg                     raw_en;

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
    wire                    s2_we;
    wire [1:0]              s2_size;
    wire [DATA_W-1:0]       s2_wdata;
    wire [TAG_W-1:0]        s2_tag, s2_snoop_tag;
    wire [INDEX_W-1:0]      s2_index, s2_snoop_index;
    wire [WORD_OFF_W-1:0]   s2_word_off;
    wire [BYTE_OFF_W-1:0]   s2_byte_off;
    wire [1:0]              s2_cmd;
    wire                    s2_is_snoop;

    // Stage 2 Atomic Signals
    wire                    s2_atomic_lr;
    wire                    s2_atomic_sc;
    wire                    s2_atomic_amo;
    wire [2:0]              s2_amo_op;
    wire                    sc_done;

    // Control Signals
    wire                    cpu_hit;
    wire                    snoop_busy;
    wire                    snoop_hit;
    wire                    snoop_can_access_ram;
    wire                    reg_snoop_stall;
    wire                    stall_contoller;
    wire                    bus_rw;

    // Memory Arrays Output
    wire [TAG_W-1:0]    tag_read    [0:NUM_WAYS-1];
    wire [LINE_W-1:0]   data_read   [0:NUM_WAYS-1];
    
    // MOESI & Hit Logic
    wire [3:0]  way_hit;
    wire [3:0]  way_select;
    wire [3:0]  way_select_final;
    wire [3:0]  choosen_way;
    wire        any_hit;
    wire [2:0]  moesi_current_state     [0:NUM_WAYS-1];
    wire [2:0]  moesi_next_state;
    wire        bus_snoop_valid;
    wire        moesi_we, snoop_moesi_we, main_moesi_we;
    wire        is_unique, is_dirty, is_owner, is_valid;
    
    // Controller Output Signals
    wire        tag_we;
    wire        refill_we;
    wire [3:0]  burst_cnt;
    wire [3:0]  burst_cnt_snoop;
    wire        use_l1_data_mux;
    wire        is_shared_response;
    wire        is_dirty_response;

    // Address Muxing
    wire [ADDR_W-1:0]   s1_mux_addr;
    wire [TAG_W-1:0]    tag_select;

    // Address Generation
    wire [ADDR_W-1:0]       s2_full_addr;
    wire [ADDR_W-1:0]       victim_addr_full;
    wire [ADDR_W-1:0]       refill_addr_full;

    // ================================================================
    // DERIVED SIGNALS
    // ================================================================
    assign s1_mux_addr      = (i_snp_req_valid) ? i_snp_req_addr : (cpu_addr | DATA_START);
    assign s2_full_addr     = {s2_tag, s2_index, s2_word_off, s2_byte_off};
    assign victim_addr_full = {victim_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign refill_addr_full = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    // assign o_l2_req_addr    = (o_l2_req_cmd[0]) ? victim_addr_full : refill_addr_full;


    assign choosen_way      = (any_hit) ? way_hit : way_select;
    assign moesi_we         = main_moesi_we | snoop_moesi_we;
    assign tag_select       = (s2_is_snoop) ? s2_snoop_tag : s2_tag;
    assign way_select_final = (any_hit) ? way_hit : way_select;

    // ================================================================
    // STAGE 1: ACCESS
    // ================================================================
    access #(
        .ADDR_W     (ADDR_W),
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS)
    ) access_inst (
        .cpu_addr       (s1_mux_addr),
        .ac_addr        (i_snp_req_addr),

        .cpu_tag        (s1_tag),            
        .ac_tag         (s1_ac_tag),
        .cpu_index      (s1_index), 
        .ac_index       (s1_ac_index),  
        .cpu_word_off   (s1_word_off),
        .cpu_byte_off   (s1_byte_off)
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
                .clk                    (clk), 
                .rst_n                  (rst_n),

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
                .clk            (clk), 
                .rst_n          (rst_n),
                // .read_index     (read_index_src ? s1_index : s2_index),  
                .read_index     (s1_index),  
                .dout           (data_read[i]),
                
                // Ghi nguyen dong cache
                .refill_we      (refill_we & way_select[i]),
                .write_index    (s2_index),
                .refill_din     (refill_buffer),
                
                .cpu_we         (data_we & way_hit[i]),
                .cpu_din        (s2_atomic_amo ? amo_alu_result : s2_wdata), // chua xu ly amo swap
                .cpu_wstrb      (4'b1111),
                .cpu_offset     (s2_word_off),
            );
        end
    endgenerate

    // ================================================================
    // PIPELINE REGISTER
    // ================================================================
    assign pipeline_stall = stall_contoller | i_snp_req_valid; 
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
        .clk        (clk), 
        .rst_n      (rst_n),
        .stall      (pipeline_stall),
        .flush      (1'b0),

        // Stage 1 Inputs (Mapped from L1 interface)
        .s1_req         (cpu_req),
        .s1_we          (cpu_we),
        .s1_size        (cpu_size),
        .s1_wdata       (cpu_din),
        .s1_tag         (s1_tag),    
        .s1_index       (s1_index),   
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),

        .snoop_stall    (reg_snoop_stall),
        .s1_is_snoop    (i_snp_req_valid),
        .s1_snoop_tag   (s1_ac_tag),
        .s1_snoop_index (s1_ac_index),

        // Inputs Atomic
        .s1_lr          (cpu_lr),
        .s1_sc          (cpu_sc),
        .s1_amo         (cpu_amo),
        .s1_amo_op      (cpu_amo_op),

        // Stage 2 Outputs
        .s2_req         (s2_req),
        .s2_we          (s2_we),
        .s2_cmd         (s2_cmd),
        .s2_size        (s2_size),
        .s2_wdata       (s2_wdata),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off),

        .s2_is_snoop    (s2_is_snoop),
        .s2_snoop_tag   (s2_snoop_tag),
        .s2_snoop_index (s2_snoop_index),

        // Outputs Atomic
        .s2_lr          (s2_atomic_lr),
        .s2_sc          (s2_atomic_sc),
        .s2_amo         (s2_atomic_amo),
        .s2_amo_op      (s2_amo_op)
    );

    // ================================================================
    // STAGE 2: HIT LOGIC
    // ================================================================
    assign way_hit[0]   = (tag_read[0] == tag_select) & (moesi_current_state[0] != 3'd4);
    assign way_hit[1]   = (tag_read[1] == tag_select) & (moesi_current_state[1] != 3'd4);
    assign way_hit[2]   = (tag_read[2] == tag_select) & (moesi_current_state[2] != 3'd4);
    assign way_hit[3]   = (tag_read[3] == tag_select) & (moesi_current_state[3] != 3'd4);

    assign snoop_hit    = |way_hit & s2_is_snoop;
    assign cpu_hit      = (|way_hit) & s2_req & ~s2_is_snoop;
    assign any_hit      = |way_hit;
    
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
    // REFILL & SNOOP BUFFER LOGIC
    // ================================================================
    // Refill Buffer: Receive data from Memory (AXI R) or L1 (Writeback)
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            refill_buffer <= {LINE_W{1'b0}};
        end 
        else begin 
            // Case 1: Refill from Snoop (AXI R Channel)
            if (i_resp_valid & o_resp_ready & (iRID == CORE_ID)) begin
                // refill_buffer[burst_cnt * DATA_W +: DATA_W] <= iRDATA;
                refill_buffer <= i_resp_data;
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
        .clk        (clk), 
        .rst_n      (rst_n),
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
        .clk        (clk), 
        .rst_n      (rst_n),

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

        // Outputs to Datapath
        .tag_we             (tag_we),
        .moesi_we           (main_moesi_we),
        .refill_we          (refill_we),
        // .read_index_src     (read_index_src),
        .stall              (stall_contoller),
        .is_shared_response (is_shared_response),
        .is_dirty_response  (is_dirty_response),
        .o_req_ready        (o_req_ready),
        .burst_cnt          (burst_cnt)
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
        .clk                    (clk), 
        .rst_n                  (rst_n),
        
        // thong tin tu L2
        .snoop_hit              (snoop_hit),
        .is_unique              (is_unique), 
        .is_dirty               (is_dirty), 
        .is_owner               (is_owner),
        .snoop_can_access_ram   (snoop_can_access_ram),
        .reg_snoop_stall        (reg_snoop_stall),
        
        // Output dieu khien L2
        .moesi_we               (snoop_moesi_we),
        .snoop_busy             (snoop_busy),
        .bus_rw                 (bus_rw),
        .bus_snoop_valid        (bus_snoop_valid),
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

    // Mux o_snp_resp_data Data (Snoop Response Data)
    always @(*) begin
        case(way_hit)
            4'b0001: o_snp_resp_data = data_read[0];
            4'b0010: o_snp_resp_data = data_read[1];
            4'b0100: o_snp_resp_data = data_read[2];
            4'b1000: o_snp_resp_data = data_read[3];
            default: o_snp_resp_data = {LINE_W{1'b0}};
        endcase
    end

endmodule