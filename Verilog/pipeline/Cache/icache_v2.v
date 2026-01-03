`timescale 1ns/1ps

module icache_v2 #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  // 16 words/line
    parameter BYTE_OFF_W    = 2,  // 4B/word
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32,
    parameter CORE_ID       = 1'b0, // 0: core 0, 1: core 1

    parameter ID_W          = 2,    // ICACHE1: 2'b10, ICACHE2: 2'b11;
    parameter USER_W        = 4,
    parameter STRB_W        = (DATA_W/8)
)(
    input ACLK, ARESETn,

    // (cache <-> cpu)
    input                       cpu_req,
    input                       icache_flush,
    input   [ADDR_W-1:0]        cpu_addr,

    output   [DATA_W-1:0]       data_rdata,
    // output                      cpu_hit,
    output                      pipeline_stall,

    // (icache <-> dcache)
    input                   dcache_stall,

    // (cache <-> cache L2) - AXI Read Only
    // AR channel
    input                   iARREADY,
    output  [ID_W-1:0]      oARID,
    output  [ADDR_W-1:0]    oARADDR,
    output  [7:0]           oARLEN,
    output  [2:0]           oARSIZE,
    output  [1:0]           oARBURST,
    output                  oARVALID,

    // R channel
    input   [ID_W-1:0]      iRID,
    input   [DATA_W-1:0]    iRDATA,
    input   [1:0]           iRRESP,
    input                   iRLAST,
    input                   iRVALID,
    output                  oRREADY
);
    // ---------------------------------------- SIGNAL DEFINITIONS & PIPELINE WIRES ----------------------------------------
    // --- Stage 1 Signals ---
    wire [TAG_W-1:0]        s1_tag;
    wire [INDEX_W-1:0]      s1_index;
    wire [WORD_OFF_W-1:0]   s1_word_off;
    wire [BYTE_OFF_W-1:0]   s1_byte_off;
    
    // --- Stage 2 Signals ---
    wire [TAG_W-1:0]        s2_tag;
    wire [INDEX_W-1:0]      s2_index;
    wire [WORD_OFF_W-1:0]   s2_word_off;
    wire [BYTE_OFF_W-1:0]   s2_byte_off;
    wire                    s2_req;

    // --- Memory & Valid Signals ---
    wire [TAG_W-1:0]        tag_read    [0:NUM_WAYS-1];
    wire [CACHE_DATA_W-1:0] data_read   [0:NUM_WAYS-1];
    reg  [NUM_WAYS-1:0]     valid       [0:NUM_SETS-1];

    // --- Control Signals ---
    wire                tag_we;
    wire                valid_we;
    wire                refill_we;
    wire                index_src;
    wire [3:0]          cache_state;
    wire [3:0]          burst_cnt;
    wire [NUM_WAYS-1:0] way_select;

    // reg [NUM_WAYS-1:0]      reg_way_select;
    reg [CACHE_DATA_W-1:0]  refill_buffer;
    
    // Hit Logic
    wire [3:0]  way_hit;
    wire        any_hit;

    // ---------------------------------------- ACCESS (ADDRESS DECODE) ----------------------------------------
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

    // ---------------------------------------- PIPELINE REGISTER (ACC_CMP) ----------------------------------------
    assign pipeline_stall   = (s2_req & ~any_hit); 

    acc_cmp #(
        .ADDR_W     (ADDR_W),
        .DATA_W     (DATA_W),
        .NUM_SETS   (NUM_SETS)
    ) acc_cmp_inst (
        .clk            (ACLK),
        .rst_n          (ARESETn),
        .stall          (pipeline_stall | dcache_stall),
        .flush          (icache_flush),

        // Stage 1
        .s1_req         (cpu_req),    
        .s1_we          (1'b0),             // I-Cache khong dung write
        .s1_size        (2'b00),    
        .s1_wdata       ({DATA_W{1'b0}}),  
        .s1_tag         (s1_tag),    
        .s1_index       (s1_index),   
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),

        // Stage 2
        .s2_req         (s2_req),
        .s2_we          (),                 // khong dung
        .s2_size        (),
        .s2_wdata       (),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off)
    );
    // ---------------------------------------- SRAM ARRAYS & VALID BITS ----------------------------------------
    wire [NUM_WAYS-1:0] current_valid_bits = valid[s2_index];

    integer k;
    always @(posedge ACLK or negedge ARESETn) begin    
        if (~ARESETn) begin
            for (k = 0; k < NUM_SETS; k = k + 1) begin
                valid[k] <= {NUM_WAYS{1'b0}};
            end 
        end 
        else begin
             if (valid_we) begin
                valid[s2_index] <= valid[s2_index] | way_select;
            end 
        end 
    end

    // ---------------------------------------- TAG RAMs ----------------------------------------
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
                .moesi_we       (1'b0),
                
                // READ PORT (Stage 1)
                .read_index     (s1_index),   
                
                // WRITE PORT (Stage 2/Refill)
                .write_index    (s2_index),           
                .din_tag        (s2_tag),            
                
                // OUTPUT (Stage 2)
                .dout_tag       (tag_read[i]),
                
                // khong dung moesi state
                .moesi_next_state   (3'b0),
                .moesi_current_state()
            );
        end
    endgenerate

    // ---------------------------------------- DATA RAMs ----------------------------------------
    generate
        for (i = 0; i < NUM_WAYS; i = i + 1) begin : data_rams
            data_mem #( 
                .DATA_W     (DATA_W), 
                .NUM_SETS   (NUM_SETS) 
            ) u_data_mem (
                .clk            (ACLK),
                .rst_n          (ARESETn),
                
                // READ PORT (Stage 1)
                .read_index     (s1_index),  
                
                // WRITE PORT (Refill only)
                .write_index    (s2_index),
                .refill_we      (refill_we & way_select[i]),
                .refill_din     (refill_buffer),
                
                // CPU Write Interface (khong dung)
                .cpu_we         (1'b0), 
                .cpu_din        ({DATA_W{1'b0}}),          
                .cpu_wstrb      ({STRB_W{1'b0}}),           
                .cpu_offset     (4'd0),

                // OUTPUT (Stage 2)
                .dout           (data_read[i])
            );
        end
    endgenerate

    // ---------------------------------------- COMPARE & OUTPUT LOGIC ----------------------------------------
    assign way_hit[0] = (tag_read[0] == s2_tag) & current_valid_bits[0];
    assign way_hit[1] = (tag_read[1] == s2_tag) & current_valid_bits[1];
    assign way_hit[2] = (tag_read[2] == s2_tag) & current_valid_bits[2];
    assign way_hit[3] = (tag_read[3] == s2_tag) & current_valid_bits[3];

    assign any_hit    = |way_hit;
    // assign cpu_hit    = any_hit;

    // Mux dau ra
    // dang phan van cho nay
    reg [DATA_W-1:0] word_select;
    always @(*) begin
        if (index_src) begin
            word_select = refill_buffer[s2_word_off * DATA_W +: DATA_W];
        end 
        else begin
            case(way_hit)
                4'b0001: word_select = data_read[0][s2_word_off * DATA_W +: DATA_W];
                4'b0010: word_select = data_read[1][s2_word_off * DATA_W +: DATA_W];
                4'b0100: word_select = data_read[2][s2_word_off * DATA_W +: DATA_W];
                4'b1000: word_select = data_read[3][s2_word_off * DATA_W +: DATA_W];
                default: word_select = 32'd0;
            endcase
        end 
    end 
    
    assign data_rdata = word_select;

    // ---------------------------------------- CONTROLLER & REPLACEMENT POLICY ----------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            refill_buffer   <= {CACHE_DATA_W{1'b0}};
            // reg_way_select  <= {NUM_WAYS{1'b0}};
        end 
        else begin
            if (iRVALID & oRREADY & (iRID == {1'b0, CORE_ID})) begin
                refill_buffer[burst_cnt * DATA_W +: DATA_W] <= iRDATA;
            end 
            // if (~any_hit & s2_req)
            //     reg_way_select <= way_select;
        end 
    end 

    // --- PLRU Replacement ---
    cache_replacement #(
        .N_WAYS     (NUM_WAYS),
        .N_LINES    (NUM_SETS)
    ) cache_replacement (
        .clk            (ACLK),
        .rst_n          (ARESETn),
        .we             (any_hit),

        .way_hit        ((any_hit) ? way_hit : way_select), 
        .addr           (s2_index),

        .way_select     (way_select)
    );

    // ---------------------------------------- AXI Addresses ----------------------------------------
    assign oARADDR = {s2_tag, s2_index, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};

    // ---------------------------------------- Main Controller ----------------------------------------
    icache_controller #(
        .DATA_W     (DATA_W),
        .ADDR_W     (ADDR_W),
        .ID_W       (ID_W),
        .USER_W     (USER_W),
        .STRB_W     (STRB_W),
        .CORE_ID    (CORE_ID),
        .BURST_LEN  (15)
    ) icache_controller(
        .clk            (ACLK),
        .rst_n          (ARESETn),

        .cpu_req        (s2_req),
        .hit            (any_hit),
        
        // Control signals output
        .tag_we         (tag_we),
        .valid_we       (valid_we),
        .refill_we      (refill_we),
        .cache_state    (cache_state),
        .burst_cnt      (burst_cnt),
        .index_src      (index_src),

        // AXI Read Channels
        .oARID          (oARID),
        .oARLEN         (oARLEN),
        .oARSIZE        (oARSIZE),
        .oARBURST       (oARBURST),
        .oARVALID       (oARVALID),
        .iARREADY       (iARREADY),

        .iRID           (iRID),
        .iRRESP         (iRRESP),
        .iRLAST         (iRLAST),
        .iRVALID        (iRVALID),
        .oRREADY        (oRREADY)  
    );

endmodule