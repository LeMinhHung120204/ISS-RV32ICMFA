`timescale 1ns/1ps

module dcache_v2 #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  // 16 words/line (64 bytes)
    parameter BYTE_OFF_W    = 2,  // 4B/word
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32, // 512 bits
    parameter CORE_ID       = 1'b0,    

    parameter ID_W          = 2,
    parameter USER_W        = 4,
    parameter STRB_W        = (DATA_W/8)
)(
    input ACLK, ARESETn,

    // --- CPU Interface ---
    input                       cpu_req, 
    input                       cpu_we,
    input   [1:0]               cpu_size,
    input   [ADDR_W-1:0]        cpu_addr,
    input   [DATA_W-1:0]        cpu_din,

    output  reg [DATA_W-1:0]    data_rdata,
    output                      cpu_hit,
    output                      cache_busy, // Stall CPU

    // (cache <-> cache L2)
    // AW channel 
    input                   iAWREADY,
    output  [ID_W-1:0]      oAWID,
    output  [ADDR_W-1:0]    oAWADDR,
    output  [7:0]           oAWLEN,
    output  [2:0]           oAWSIZE,
    output  [1:0]           oAWBURST,   
    output                  oAWLOCK,    // khong dun
    output  [3:0]           oAWCACHE,   // khong dun
    output  [2:0]           oAWPROT,    // khong dung
    output  [3:0]           oAWQOS,     // khong dung
    output  [3:0]           oAWREGION,  // khong dung
    output  [USER_W-1:0]    oAWUSER,    // khong dung
    output                  oAWVALID,
    // tin hieu them
    output  [2:0]           oAWSNOOP,
    output  [1:0]           oAWDOMAIN,
    output  [1:0]           oAWBAR,     // must be 1'b0: normal access
    output                  oAWUNIQUE,  // khong dung (=0) vi khong co cache L3
    
    // W channel
    input                       iWREADY,
    output reg  [DATA_W-1:0]    oWDATA,
    output  [STRB_W-1:0]        oWSTRB,
    output                      oWLAST,
    output  [USER_W-1:0]        oWUSER,     // khong dun
    output                      oWVALID,
    
    // B channel
    input   [ID_W-1:0]      iBID,
    input   [1:0]           iBRESP,
    input   [USER_W-1:0]    iBUSER,     // khong dun
    input                   iBVALID,
    output                  oBREADY,

    // AR channel
    input                   iARREADY,
    output  [ID_W-1:0]      oARID,
    output  [ADDR_W-1:0]    oARADDR,
    output  [7:0]           oARLEN,
    output  [2:0]           oARSIZE,
    output  [1:0]           oARBURST,
    output                  oARLOCK,    // khong dun
    output  [3:0]           oARCACHE,   // khong dun
    output  [2:0]           oARPROT,    // khong dung
    output  [3:0]           oARQOS,     // khong dun
    output  [USER_W-1:0]    oARUSER,    // khong dun
    output                  oARVALID,
    // tin hieu them
    output  [3:0]           oARSNOOP,
    output  [1:0]           oARDOMAIN,
    output  [1:0]           oARBAR,     // must be 1'b0: normal access

    // R channel
    input   [ID_W-1:0]      iRID,
    input   [DATA_W-1:0]    iRDATA,
    //  RRESP[3:2] (interconnect)
    //  RRESP[1:0] (memory)
    input   [3:0]           iRRESP,
    input                   iRLAST,
    input   [USER_W-1:0]    iRUSER,   // khong dun
    input                   iRVALID,
    output                  oRREADY,

    // Snoop channel
    // AC channel
    input                   iACVALID,
    input   [ADDR_W-1:0]    iACADDR,
    input   [3:0]           iACSNOOP,
    input   [2:0]           iACPROT,    // khong dung
    output                  oACREADY,

    // CR channel
    input                   iCRREADY,
    output                  oCRVALID,
    output  [4:0]           oCRRESP,
    
    // CD channel
    input                       iCDREADY,
    output                      oCDVALID,
    output reg  [DATA_W-1:0]    oCDDATA,
    output                      oCDLAST
);
    wire [TAG_W-1:0]        s1_tag;
    wire [INDEX_W-1:0]      s1_index;
    wire [WORD_OFF_W-1:0]   s1_word_off;
    wire [BYTE_OFF_W-1:0]   s1_byte_off;

    wire                    s2_req;
    wire                    s2_we;
    wire [1:0]              s2_size;
    wire [DATA_W-1:0]       s2_wdata;
    wire [TAG_W-1:0]        s2_tag;
    wire [INDEX_W-1:0]      s2_index;
    wire [WORD_OFF_W-1:0]   s2_word_off;
    wire [BYTE_OFF_W-1:0]   s2_byte_off;

    // ---------------------------------------- Snoop & Control Signals ----------------------------------------
    wire snoop_busy;
    wire snoop_can_access_ram;
    wire [INDEX_W-1:0] snoop_index = iACADDR[BYTE_OFF_W + WORD_OFF_W + INDEX_W - 1 : BYTE_OFF_W + WORD_OFF_W];
    wire [TAG_W-1:0]   snoop_tag   = iACADDR[ADDR_W-1 : ADDR_W - TAG_W];

    // ---------------------------------------- Memory Interface Signals ----------------------------------------
    wire [INDEX_W-1:0]      ram_access_index;
    wire [TAG_W-1:0]        tag_read    [0:NUM_WAYS-1];
    wire [CACHE_DATA_W-1:0] data_read   [0:NUM_WAYS-1];
    
    // ---------------------------------------- Hit/Miss & MOESI ----------------------------------------
    wire [3:0]  way_hit;
    wire        any_hit;
    wire [2:0]  moesi_current_state     [0:NUM_WAYS-1];
    reg  [2:0]  moesi_selected_state;
    wire [2:0]  moesi_next_state;
    wire        moesi_we;
    wire        is_unique, is_dirty, is_owner, is_valid;
    
    // ---------------------------------------- Controller Signals ----------------------------------------
    wire                    main_tag_we, snoop_tag_we, tag_we;
    wire                    refill_we;
    wire                    data_we;

    reg  [CACHE_DATA_W-1:0] refill_buffer;
    wire [3:0]              burst_cnt;
    wire [3:0]              burst_cnt_snoop;

    wire [NUM_WAYS-1:0]     way_select;
    reg  [NUM_WAYS-1:0]     reg_way_select;
    
    // ---------------------------------------- STAGE 1: ACCESS & SNOOP MUX ----------------------------------------
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

    assign ram_access_index = (snoop_can_access_ram) ? snoop_index : s1_index;

    // ---------------------------------------- SRAM ARRAYS (DATA & TAG) ----------------------------------------
    assign tag_we = main_tag_we | snoop_tag_we;
    wire [3:0] choosen_way = (any_hit) ? way_hit : way_select;

    // Tag ram
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
                .moesi_we       (moesi_we & choosen_way[i]),
                .read_index     (ram_access_index),   
                .write_index    (s2_index),           
                .din_tag        (s2_tag),            
                
                .dout_tag               (tag_read[i]),
                .moesi_next_state       (moesi_next_state),
                .moesi_current_state    (moesi_current_state[i])
            );
        end
    endgenerate

    generate
        for (i = 0; i < NUM_WAYS; i = i + 1) begin : data_rams
            data_mem #( 
                .DATA_W     (DATA_W), 
                .NUM_SETS   (NUM_SETS) 
            ) u_data_mem (
                .clk            (ACLK),
                .rst_n          (ARESETn),
                .read_index     (ram_access_index),  
                .write_index    (s2_index),
                
                .refill_we      (refill_we & way_select[i]),
                .refill_din     (refill_buffer),
                
                .cpu_we         (data_we),            
                .cpu_din        (s2_wdata),          
                .cpu_wstrb      (4'b1111),           
                .cpu_offset     (s2_word_off),

                .dout           (data_read[i])
            );
        end
    endgenerate

    // ---------------------------------------- PIPELINE REGISTER (ACC_CMP) ----------------------------------------
    wire pipeline_stall = cache_busy | (snoop_busy & !snoop_can_access_ram); 
    wire pipeline_flush = 1'b0;

    acc_cmp #(
        .ADDR_W     (ADDR_W),
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS)
    ) acc_cmp_inst (
        .clk            (ACLK),
        .rst_n          (ARESETn),
        .stall          (pipeline_stall),
        .flush          (pipeline_flush),

        // Stage 1
        .s1_req         (cpu_req),    
        .s1_we          (cpu_we),      
        .s1_size        (cpu_size),    
        .s1_wdata       (cpu_din),  
        .s1_tag         (s1_tag),    
        .s1_index       (s1_index),   
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),
        .s1_snoop_tag   (snoop_tag),
        .s1_snoop_index (snoop_index),

        // Stage 2
        .s2_req         (s2_req),
        .s2_we          (s2_we),
        .s2_size        (s2_size),
        .s2_wdata       (s2_wdata),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off),
        .s2_snoop_tag   (s2_snoop_tag),
        .s2_snoop_index (s2_snoop_index)
    );

    // ---------------------------------------- STAGE 2: COMPARE & HIT LOGIC ----------------------------------------
    wire [TAG_W-1:0] tag_compare_input = (snoop_busy) ? snoop_tag : s2_tag;

    assign way_hit[0]   = (tag_read[0] == tag_compare_input) & (moesi_current_state[0] != 3'd4); // 4 = Invalid
    assign way_hit[1]   = (tag_read[1] == tag_compare_input) & (moesi_current_state[1] != 3'd4);
    assign way_hit[2]   = (tag_read[2] == tag_compare_input) & (moesi_current_state[2] != 3'd4);
    assign way_hit[3]   = (tag_read[3] == tag_compare_input) & (moesi_current_state[3] != 3'd4);

    assign any_hit      = |way_hit;
    assign cpu_hit      = (snoop_busy) ? 1'b0 : any_hit;
    
    always @(*) begin
        case (way_hit)
            4'b0001: moesi_selected_state = moesi_current_state[0];
            4'b0010: moesi_selected_state = moesi_current_state[1];
            4'b0100: moesi_selected_state = moesi_current_state[2];
            4'b1000: moesi_selected_state = moesi_current_state[3];
            default: moesi_selected_state = 3'd4; // Invalid
        endcase
    end

    // ---------------------------------------- DATA OUTPUT MUX (READ LOGIC) ----------------------------------------
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

    // ---------------------------------------- CONTROLLERS & SUPPORT MODULES ----------------------------------------
    // Refill Buffer Logic
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            refill_buffer   <= {CACHE_DATA_W{1'b0}};
            reg_way_select  <= {NUM_WAYS{1'b0}};
        end 
        else begin 
            if (iRVALID & oRREADY & (iRID == {1'b1, CORE_ID})) begin
                refill_buffer <= {iRDATA, refill_buffer[CACHE_DATA_W - DATA_W : DATA_W]};
            end 
            if (~any_hit & s2_req)
                reg_way_select <= way_select;
        end 
    end 

    // Cache Replacement Policy (PLRU)
    wire [INDEX_W-1:0] plru_target_index = (snoop_busy) ? snoop_index : s2_index;
    wire plru_we;
    
    cache_replacement #( 
        .N_WAYS     (NUM_WAYS), 
        .N_LINES    (NUM_SETS) 
    ) u_replacement (
        .clk        (ACLK),
        .rst_n      (ARESETn),
        .we         (plru_we),
        .way_hit    (plru_src ? way_hit : reg_way_select),
        .addr       (plru_target_index),
        .way_select (way_select)
    );

    // ---------------------------------------- Main Cache Controller ----------------------------------------
    cache_controller #(
        .DATA_W     (DATA_W),
        .ADDR_W     (ADDR_W),
        .CORE_ID    (CORE_ID)
    ) dcache_controller (
        .clk        (ACLK),
        .rst_n      (ARESETn),

        // Inputs
        .snoop_busy             (snoop_busy),
        .snoop_can_access_ram   (snoop_can_access_ram),
        .wb_error               (wb_error),
        .cpu_req                (s2_req),        
        .cpu_we                 (s2_we),
        .hit                    (any_hit),
        .victim_dirty           (is_dirty),      
        .is_valid               (is_valid),
        .current_moesi_state    (moesi_selected_state),

        // Outputs
        .cache_busy         (cache_busy),
        .data_we            (data_we),
        .tag_we             (main_tag_we),
        .moesi_we           (moesi_we),
        .refill_we          (refill_we),
        .burst_cnt          (burst_cnt),
        .plru_we            (plru_we  ),
        .plru_src           (plru_src ),
        .is_shared_response (is_shared_response),
        .is_dirty_response  (is_dirty_response ),
        .cache_state        (cache_state),

        // cache <-> mem
        // AW channel
        .oAWLEN          (oAWLEN   ),
        .oAWSIZE         (oAWSIZE  ),
        .oAWBURST        (oAWBURST ),
        .oAWLOCK         (oAWLOCK  ),
        .oAWCACHE        (oAWCACHE ),
        .oAWPROT         (oAWPROT  ),
        .oAWQOS          (oAWQOS   ),
        .oAWREGION       (oAWREGION),
        .oAWUSER         (oAWUSER  ),
        .oAWVALID        (oAWVALID ),
        .iAWREADY        (iAWREADY ),
        // ACE extenstion
        .oAWSNOOP       (oAWSNOOP ),
        .oAWDOMAIN      (oAWDOMAIN),
        .oAWBAR         (oAWBAR   ),
        .oAWUNIQUE      (oAWUNIQUE),

        // W channel
        .oWSTRB          (oWSTRB ),
        .oWLAST          (oWLAST ),
        .oWUSER          (oWUSER ),
        .oWVALID         (oWVALID),
        .iWREADY         (iWREADY),

        // B channel
        .iBID            (iBID   ),   
        .iBRESP          (iBRESP ), 
        .iBUSER          (iBUSER ),
        .iBVALID         (iBVALID),
        .oBREADY         (oBREADY),

        // AR channel
        .oARLEN          (oARLEN  ),
        .oARSIZE         (oARSIZE ),
        .oARBURST        (oARBURST),
        .oARLOCK         (oARLOCK ),
        .oARCACHE        (oARCACHE),
        .oARPROT         (oARPROT ),
        .oARQOS          (oARQOS  ),
        .oARUSER         (oARUSER ),
        .oARVALID        (oARVALID),
        .iARREADY        (iARREADY),
        // ACE extension
        .oARSNOOP        (oARSNOOP ),
        .oARDOMAIN       (oARDOMAIN),
        .oARBAR          (oARBAR   ),

        // R channel
        .iRID            (iRID   ),  
        .iRRESP          (iRRESP ),
        .iRLAST          (iRLAST ),
        .iRUSER          (iRUSER ),
        .iRVALID         (iRVALID),
        .oRREADY         (oRREADY)
    );
    
    assign oAWADDR = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign oARADDR = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};

    // ---------------------------------------- Snoop Controller & MOESI Controller ----------------------------------------
    snoop_controller #( 
        .ADDR_W(ADDR_W) 
    ) u_snoop_ctrl (
        .clk                    (ACLK),
        .rst_n                  (ARESETn),
        .snoop_hit              (snoop_hit),

        .is_unique              (is_unique),
        .is_dirty               (is_dirty ),
        .is_owner               (is_owner ),

        .snoop_can_access_ram   (snoop_can_access_ram),
        .tag_we                 (snoop_tag_we        ),
        .snoop_busy             (snoop_busy          ),
        .bus_rw                 (bus_rw              ),
        .bus_snoop_valid        (bus_snoop_valid     ),
        .burst_cnt_snoop        (burst_cnt_snoop     ),

        // AC channel
        .ACVALID    (iACVALID),
        .ACSNOOP    (iACSNOOP),
        .ACPROT     (iACPROT ),
        .ACREADY    (oACREADY),

        // CR channel
        .CRREADY    (iCRREADY),
        .CRVALID    (oCRVALID),
        .CRRESP     (oCRRESP ),

        // CD channel
        .CDREADY    (iCDREADY),
        .CDLAST     (oCDLAST ),
        .CDVALID    (oCDVALID)
    );
    
    moesi_controller u_moesi_ctrl (
        .is_shared_response (is_shared_response),
        .is_dirty_response  (is_dirty_response ),
        .current_state      (choosen_moesi),

        .cpu_req_valid      (cpu_req),
        .cpu_hit            (cpu_hit),
        .cpu_rw             (cpu_we ),

        
        .bus_snoop_valid    (bus_snoop_valid),
        .snoop_hit          (snoop_hit      ),
        .bus_rw             (bus_rw         ),
        
        .is_dirty           (is_dirty ),
        .is_unique          (is_unique),
        .is_owner           (is_owner ),
        .is_valid           (is_valid ),

        .next_state         (moesi_next_state)
    );

    // Mux Write Data cho Bus (Evict/Snoop Response)
    always @(*) begin
        case(choosen_way)
            4'b0001: oWDATA = data_read[0][burst_cnt * DATA_W +: DATA_W];
            4'b0010: oWDATA = data_read[1][burst_cnt * DATA_W +: DATA_W];
            4'b0100: oWDATA = data_read[2][burst_cnt * DATA_W +: DATA_W];
            4'b1000: oWDATA = data_read[3][burst_cnt * DATA_W +: DATA_W];
            default: oWDATA = 32'd0;
        endcase
    end
    
    // Mux CD Data (Snoop Data Response)
    always @(*) begin
        case(way_hit)
            4'b0001: oCDDATA = data_read[0][burst_cnt_snoop * DATA_W +: DATA_W];
            4'b0010: oCDDATA = data_read[1][burst_cnt_snoop * DATA_W +: DATA_W];
            4'b0100: oCDDATA = data_read[2][burst_cnt_snoop * DATA_W +: DATA_W];
            4'b1000: oCDDATA = data_read[3][burst_cnt_snoop * DATA_W +: DATA_W];
            default: oCDDATA = 32'd0;
        endcase
    end

endmodule