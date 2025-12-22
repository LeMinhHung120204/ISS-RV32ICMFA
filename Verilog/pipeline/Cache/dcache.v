`timescale 1ns/1ps
module dcache #(
    parameter ADDR_W        = 32,
    parameter DATA_W        = 32,
    parameter NUM_WAYS      = 4,
    parameter NUM_SETS      = 16,
    parameter INDEX_W       = $clog2(NUM_SETS),
    parameter WORD_OFF_W    = 4,  // 16 words/line
    parameter BYTE_OFF_W    = 2,  // 4B/word
    parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W,
    parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32,

    parameter ID_W          = 2,    // ICACHE1: 2'b10, ICACHE2: 2'b11;
    parameter USER_W        = 4,
    parameter STRB_W        = (DATA_W/8)

)(
    input ACLK, ARESETn,

    // (cache <-> cpu)
    input                       cpu_req, cpu_we,
    input   [1:0]               cpu_size, // 00: word, 01: byte, 10: half
    input                       data_valid,
    input   [ADDR_W-1:0]        cpu_addr,
    input   [DATA_W-1:0]        cpu_din,

    output  reg [DATA_W-1:0]    data_rdata,
    output                      cpu_hit,
    output                      cache_busy,

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
    output  [ID_W-1:0]          oWID,
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
    localparam BO       = BYTE_OFF_W;
    localparam WO       = WORD_OFF_W;
    localparam IX       = INDEX_W;
    localparam TAG_LSB  = BO + WO + IX;
    localparam TAG_MSB  = ADDR_W-1;
    localparam IDX_MSB  = TAG_LSB-1;
    localparam IDX_LSB  = BO + WO;
    localparam WO_MSB   = IDX_LSB-1;

    reg [ADDR_W-1:0]        reg_addr;
    reg [DATA_W-1:0]        reg_data;
    reg [ADDR_W-1:0]        reg_ACADDR;
    reg [NUM_WAYS-1:0]      reg_way_select;
    reg                     reg_cpu_req;
    reg [CACHE_DATA_W-1:0]  refill_buffer;

    // ---------------------------------------- cpu address request  ----------------------------------------

    wire [WO-1:0]       cpu_word_off    = cpu_addr[WO_MSB:BO];
    wire [IX-1:0]       cpu_index       = cpu_addr[IDX_MSB:IDX_LSB];
    // wire [TAG_W-1:0]    cpu_tag         = cpu_addr[TAG_MSB:TAG_LSB];

    wire [TAG_W-1:0]    cpu_tag_reg     = reg_addr[TAG_MSB:TAG_LSB];
    wire [IX-1:0]       cpu_index_reg   = reg_addr[IDX_MSB:IDX_LSB];
    wire [WO-1:0]       cpu_word_off_reg= reg_addr[WO_MSB:BO];
    wire [BO-1:0]       cpu_byte_off    = reg_addr[BO-1:0]; 

    // ---------------------------------------- snoop address request  ----------------------------------------
    wire [TAG_W-1:0]    snoop_tag       = reg_ACADDR[TAG_MSB:TAG_LSB];
    wire [IX-1:0]       snoop_index     = reg_ACADDR[IDX_MSB:IDX_LSB];
    // wire [WO-1:0]       snoop_word_off  = reg_ACADDR[WO_MSB:BO];
    // wire [BO-1:0]       snoop_byte_off  = reg_ACADDR[BO-1:0]; 

    wire victim_dirty;
    wire is_valid;

    // plru control
    wire plru_we;
    wire plru_src;

    // snoop_control
    wire snoop_hit, snoop_busy;
    wire snoop_we_state;
    wire snoop_can_access_ram;
    wire bus_rw;
    wire bus_snoop_valid;
    // control moesi
    wire        moesi_we;
    reg  [2:0]  moesi_selected_state;
    wire [2:0]  moesi_current_state0;
    wire [2:0]  moesi_current_state1;
    wire [2:0]  moesi_current_state2;
    wire [2:0]  moesi_current_state3;
    wire [2:0]  moesi_next_state;
    wire        is_unique, is_dirty, is_owner ;

    // control cache
    wire [3:0]  cache_state;
    wire        data_we;
    wire        main_tag_we, snoop_tag_we, tag_we;
    wire        refill_we;
    // wire        cache_busy;
    wire        is_shared_response;
    wire        is_dirty_response;
    wire        wb_error;
    wire [3:0]  burst_cnt;
    wire [3:0]  burst_cnt_snoop;

    // tag_read and mem_Read
    wire [INDEX_W-1:0]      target_index;
    wire [TAG_W-1:0]        tag_read0, tag_read1, tag_read2, tag_read3;
    wire [CACHE_DATA_W-1:0] data_read0, data_read1, data_read2, data_read3;

    // select way
    wire [NUM_WAYS-1:0]     way_select;

    // ---------------------------------------- gan ID  ----------------------------------------
//    assign oAWID    = {ID_W{1'b0}};
//    assign oWID     = {ID_W{1'b0}};

    // ---------------------------------------- check hit  ----------------------------------------
    wire [TAG_W-1:0]    tag_compare_input;
    wire [3:0]          way_hit;

    assign tag_compare_input    = (snoop_busy) ? snoop_tag : cpu_tag_reg;
    assign way_hit[0]           = (tag_read0 == tag_compare_input) & (moesi_current_state0 != 3'd4);
    assign way_hit[1]           = (tag_read1 == tag_compare_input) & (moesi_current_state1 != 3'd4);
    assign way_hit[2]           = (tag_read2 == tag_compare_input) & (moesi_current_state2 != 3'd4);
    assign way_hit[3]           = (tag_read3 == tag_compare_input) & (moesi_current_state3 != 3'd4);

    wire any_hit                = |way_hit;
    assign cpu_hit              = (snoop_busy) ? 1'b0       : any_hit;
    assign snoop_hit            = (snoop_busy) ? any_hit    : 1'b0;

    // ---------------------------------------- mux moesi  ----------------------------------------
    
    always @(*) begin
        // Mặc định
        moesi_selected_state = 3'd4;    // Invalid

        case (way_hit)
            4'b0001: moesi_selected_state = moesi_current_state0;
            4'b0010: moesi_selected_state = moesi_current_state1;
            4'b0100: moesi_selected_state = moesi_current_state2;
            4'b1000: moesi_selected_state = moesi_current_state3;
            default: begin
                moesi_selected_state = 3'd4;    // Invalid
            end
        endcase
    end

    // ---------------------------------------- refill buffer  ----------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            refill_buffer <= {CACHE_DATA_W{1'b0}};
        end 
        else begin
            if (iRVALID & oRREADY) begin
                refill_buffer <= {refill_buffer[479:0], iRDATA};
            end 
        end 
    end 

    // ---------------------------------------- sequent ----------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            reg_addr        <= 32'd0;
            reg_data        <= 32'd0;
            reg_ACADDR      <= 32'd0;
            reg_way_select  <= {NUM_WAYS{1'b0}};
            reg_cpu_req     <= 1'b0;
        end 
        else begin
            if (data_valid & (cache_state == 4'd1)) begin  // cpu request in TAG_CHECK
                reg_addr    <= cpu_addr;
                reg_data    <= cpu_din;
                reg_cpu_req <= cpu_req;
            end 
            else begin
                reg_cpu_req <= 1'b0;
            end 
            if (iACVALID & (~snoop_busy)) begin  // snoop request
                reg_ACADDR  <= iACADDR;
            end 
            if (~any_hit) begin
                reg_way_select <= way_select;
            end 
        end 
    end 

    // ---------------------------------------- Mux output ----------------------------------------
    // mux for data_rdata
    // always @(*) begin
    //     case(way_hit)
    //         4'b0001: begin
    //             data_rdata = data_read0[cpu_word_off_reg * DATA_W +: DATA_W];
    //         end 
    //         4'b0010: begin
    //             data_rdata = data_read1[cpu_word_off_reg * DATA_W +: DATA_W];
    //         end 
    //         4'b0100: begin
    //             data_rdata = data_read2[cpu_word_off_reg * DATA_W +: DATA_W];
    //         end 
    //         4'b1000: begin
    //             data_rdata = data_read3[cpu_word_off_reg * DATA_W +: DATA_W];
    //         end 
    //         default: begin
    //             data_rdata = 32'd0;
    //         end 
    //     endcase
    // end 
    reg [DATA_W-1:0]  word_select;
    always @(*) begin
        case(way_hit)
            4'b0001: begin
                word_select = data_read0[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            4'b0010: begin
                word_select = data_read1[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            4'b0100: begin
                word_select = data_read2[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            4'b1000: begin
                word_select = data_read3[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            default: begin
                word_select = 32'd0;
            end 
        endcase
    end 

    always @(*) begin
        case(cpu_size)
            2'b00: begin
                data_rdata = word_select;
            end 
            2'b01: begin
                case(cpu_byte_off)
                    2'b00: data_rdata = {24'd0, word_select[7:0]};
                    2'b01: data_rdata = {24'd0, word_select[15:8]};
                    2'b10: data_rdata = {24'd0, word_select[23:16]};
                    2'b11: data_rdata = {24'd0, word_select[31:24]};
                    default: data_rdata = {24'd0, word_select[7:0]};
                endcase
            end 
            2'b10: begin
                case(cpu_byte_off[0])
                    1'b0: data_rdata = {16'd0, word_select[15:0]};
                    1'b1: data_rdata = {16'd0, word_select[31:16]};
                    default: data_rdata = {16'd0, word_select[15:0]};
                endcase
            end
            default: data_rdata = word_select;
        endcase
    end

    // mux for write data in mem
    always @(*) begin
        case(way_select)
            4'b0001: begin
                oWDATA = data_read0[burst_cnt * DATA_W +: DATA_W];
            end 
            4'b0010: begin
                oWDATA = data_read1[burst_cnt * DATA_W +: DATA_W];
            end 
            4'b0100: begin
                oWDATA = data_read2[burst_cnt * DATA_W +: DATA_W];
            end 
            4'b1000: begin
                oWDATA = data_read3[burst_cnt * DATA_W +: DATA_W];
            end 
            default: begin
                oWDATA = 32'd0;
            end 
        endcase
    end

    // mux for CD data output
    always @(*) begin
        case(way_select)
            4'b0001: begin
                oCDDATA = data_read0[burst_cnt_snoop * DATA_W +: DATA_W];
            end 
            4'b0010: begin
                oCDDATA = data_read1[burst_cnt_snoop * DATA_W +: DATA_W];
            end 
            4'b0100: begin
                oCDDATA = data_read2[burst_cnt_snoop * DATA_W +: DATA_W];
            end 
            4'b1000: begin
                oCDDATA = data_read3[burst_cnt_snoop * DATA_W +: DATA_W];
            end 
            default: begin
                oCDDATA = 32'd0;
            end 
        endcase
    end

    // ---------------------------------------- data mem ----------------------------------------
    // way 0
    data_mem #(
        .DATA_W     (DATA_W  ),
        .NUM_SETS   (NUM_SETS)
        // .BURST_LEN_W(4)
    ) data_mem_way0 (
        .clk        (ACLK   ),
        .rst_n      (ARESETn),
        .read_index (cpu_index    ),
        .write_index(cpu_index_reg),

        .refill_we  (refill_we & way_select[0]),    
        .refill_din (refill_buffer),

        .cpu_we     (data_we),        
        .cpu_din    (reg_data),
        .cpu_wstrb  (4'b1111),      // tam de 1111
        .cpu_offset (cpu_word_off),

        .dout       (data_read0)        
    );

    // way 1
    data_mem #(
        .DATA_W     (DATA_W  ),
        .NUM_SETS   (NUM_SETS)
    ) data_mem_way1 (
        .clk        (ACLK   ),
        .rst_n      (ARESETn),
        .read_index (cpu_index    ),
        .write_index(cpu_index_reg),

        .refill_we  (refill_we & way_select[1]),    
        .refill_din (refill_buffer),

        .cpu_we     (data_we),        
        .cpu_din    (reg_data),
        .cpu_wstrb  (4'b1111),      // tam de 1111
        .cpu_offset (cpu_word_off),

        .dout       (data_read1)        
    );

    // way 2
    data_mem #(
        .DATA_W     (DATA_W  ),
        .NUM_SETS   (NUM_SETS)
    ) data_mem_way2 (
        .clk        (ACLK   ),
        .rst_n      (ARESETn),
        .read_index (cpu_index    ),
        .write_index(cpu_index_reg),

        .refill_we  (refill_we & way_select[2]),    
        .refill_din (refill_buffer),

        .cpu_we     (data_we),        
        .cpu_din    (reg_data),
        .cpu_wstrb  (4'b1111),      // tam de 1111
        .cpu_offset (cpu_word_off),

        .dout       (data_read2)        
    );

    // way 3
    data_mem #(
        .DATA_W     (DATA_W  ),
        .NUM_SETS   (NUM_SETS)
    ) data_mem_way3 (
        .clk        (ACLK   ),
        .rst_n      (ARESETn),
        .read_index (cpu_index    ),
        .write_index(cpu_index_reg),

        .refill_we  (refill_we & way_select[3]),    
        .refill_din (refill_buffer),

        .cpu_we     (data_we),        
        .cpu_din    (reg_data),
        .cpu_wstrb  (4'b1111),      // tam de 1111
        .cpu_offset (cpu_word_off),

        .dout       (data_read3)        
    );

    // ---------------------------------------- xu ly address read ----------------------------------------

    assign oARADDR = {cpu_tag_reg, cpu_index_reg, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign oAWADDR = {cpu_tag_reg, cpu_index_reg, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    // ---------------------------------------- cpu_tag mem ----------------------------------------



    wire [3:0] choosen_way;
    reg  [2:0] choosen_moesi;

    assign choosen_way      = (any_hit) ? way_hit : way_select;
    assign tag_we           = main_tag_we | snoop_tag_we;
    
    always @(*) begin
        case (choosen_way)
            4'b0001: begin
                choosen_moesi = moesi_current_state0;
            end 
            4'b0010: begin
                choosen_moesi = moesi_current_state1;
            end 
            4'b0100: begin
                choosen_moesi = moesi_current_state2;
            end 
            4'b1000: begin
                choosen_moesi = moesi_current_state3;
            end 
            default: begin
                choosen_moesi = moesi_current_state0;
            end 
        endcase
    end

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way0 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[0]),
        .moesi_we           (moesi_we & choosen_way[0]),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read0),
        .moesi_next_state   (moesi_next_state   ),
        .moesi_current_state(moesi_current_state0)
    ); 

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way1 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[1]),
        .moesi_we           (moesi_we & choosen_way[1]),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read1),
        .moesi_next_state   (moesi_next_state   ),
        .moesi_current_state(moesi_current_state1)
    ); 

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way2 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[2]),
        .moesi_we           (moesi_we & choosen_way[2]),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read2),
        .moesi_next_state   (moesi_next_state   ),
        .moesi_current_state(moesi_current_state2)
    ); 

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way3 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[3]),
        .moesi_we           (moesi_we & choosen_way[3]),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read3),
        .moesi_next_state   (moesi_next_state   ),
        .moesi_current_state(moesi_current_state3)
    ); 
    // ---------------------------------------- policy replacement ----------------------------------------

    assign target_index = (snoop_busy) ? snoop_index : cpu_index_reg;

    cache_replacement #(
        .N_WAYS     (NUM_WAYS),
        .N_LINES    (NUM_SETS)
    ) cache_replacement (
        .clk            (ACLK   ),
        .rst_n          (ARESETn),
        .we             (plru_we),
        .way_hit        ((plru_src) ? reg_way_select : way_hit),
        .addr           (target_index),

        .way_select     (way_select)
        // .way_select_bin (way_select_bin )
    );
    // ---------------------------------------- controller ----------------------------------------
    cache_controller #(
        .DATA_W     (DATA_W),
        .ADDR_W     (ADDR_W),
        .ID_W       (ID_W),
        .USER_W     (USER_W),
        .STRB_W     (STRB_W),
        .BURST_LEN  (15)
    ) dcache_controller(
        .clk            (ACLK),
        .rst_n          (ARESETn),

        .snoop_busy             (snoop_busy),
        .snoop_can_access_ram   (snoop_can_access_ram),
        .wb_error               (wb_error),

        .cpu_req                (reg_cpu_req),
        .cpu_we                 (cpu_we  ),
        .hit                    (any_hit ),
        .victim_dirty           (is_dirty),
        .is_valid               (is_valid),
        .current_moesi_state    (moesi_selected_state),

        // control datapath
        .data_we            (data_we   ),
        .tag_we             (main_tag_we),
        .moesi_we           (moesi_we ),
        .plru_we            (plru_we  ),
        .plru_src           (plru_src ),
        .refill_we          (refill_we ),
        .cache_busy         (cache_busy),
        .is_shared_response (is_shared_response),
        .is_dirty_response  (is_dirty_response ),
        .cache_state        (cache_state),
        .burst_cnt          (burst_cnt),

        // cache <-> mem
        // AW channel
        .oAWID           (oAWID    ),
        // oAWADDR         (oAWADDR  ),
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
        .oWID            (oWID   ),  
        // oWDATA          (oWDATA ),
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
        .oARID           (oARID   ),
        // oARADDR         (oARADDR ),
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
        // iRDATA          (iRDATA ),
        .iRRESP          (iRRESP ),
        .iRLAST          (iRLAST ),
        .iRUSER          (iRUSER ),
        .iRVALID         (iRVALID),
        .oRREADY         (oRREADY)
    );

    snoop_controller #(
        .ADDR_W (ADDR_W)
    ) snoop_controller (
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
//        .ACADDR     (iACADDR ),
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

    moesi_controller moesi_controller (
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
endmodule 