`timescale 1ns/1ps
module icache #(
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
    input                       cpu_req,
    input                       data_valid,
    input   [ADDR_W-1:0]        cpu_addr,

    output  reg [DATA_W-1:0]    data_rdata,
    output                      cpu_hit,

    // (cache <-> cache L2)
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
    //  RRESP[1:0] (memory)
    input   [1:0]           iRRESP,
    input                   iRLAST,
    input                   iRVALID,
    output                  oRREADY
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
    reg [NUM_WAYS-1:0]      reg_way_select;
    reg                     reg_cpu_req;
    reg [CACHE_DATA_W-1:0]  refill_buffer;
    reg [NUM_WAYS-1:0]      valid [0:NUM_SETS-1];

    // ---------------------------------------- cpu address request  ----------------------------------------

    wire [WO-1:0]       cpu_word_off    = cpu_addr[WO_MSB:BO];
    wire [IX-1:0]       cpu_index       = cpu_addr[IDX_MSB:IDX_LSB];

    wire [TAG_W-1:0]    cpu_tag_reg     = reg_addr[TAG_MSB:TAG_LSB];
    wire [IX-1:0]       cpu_index_reg   = reg_addr[IDX_MSB:IDX_LSB];
    wire [WO-1:0]       cpu_word_off_reg= reg_addr[WO_MSB:BO];
    wire [BO-1:0]       cpu_byte_off    = reg_addr[BO-1:0]; 

    // plru control
    wire plru_we;
    wire plru_src;

    // control cache
    wire [3:0]  cache_state;
    wire        valid_we;
    wire        tag_we;
    wire        refill_we;
    wire        cache_busy;
    wire [3:0]  burst_cnt;

    // tag_read and mem_Read
    wire [TAG_W-1:0]        tag_read0, tag_read1, tag_read2, tag_read3;
    wire [CACHE_DATA_W-1:0] data_read0, data_read1, data_read2, data_read3;

    // select way
    wire [NUM_WAYS-1:0]     way_select;
    // ---------------------------------------- check hit  ----------------------------------------
    wire [3:0] way_hit;

    assign way_hit[0]   = (tag_read0 == cpu_tag_reg) & valid[cpu_index_reg][0];
    assign way_hit[1]   = (tag_read1 == cpu_tag_reg) & valid[cpu_index_reg][1];
    assign way_hit[2]   = (tag_read2 == cpu_tag_reg) & valid[cpu_index_reg][2];
    assign way_hit[3]   = (tag_read3 == cpu_tag_reg) & valid[cpu_index_reg][3];

    wire any_hit        = |way_hit;
    assign cpu_hit      = any_hit;

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
            reg_way_select  <= {NUM_WAYS{1'b0}};
            reg_cpu_req     <= 1'b0;
        end 
        else begin
            if (data_valid & (cache_state == 4'd1)) begin  // cpu request in TAG_CHECK
                reg_addr    <= cpu_addr;
                reg_cpu_req <= cpu_req;
            end 
            else begin
                reg_cpu_req <= 1'b0;
            end 
            if (~any_hit) begin
                reg_way_select <= way_select;
            end 
        end 
    end 

    // ---------------------------------------- Mux output ----------------------------------------
    always @(*) begin
        case(way_hit)
            4'b0001: begin
                data_rdata = data_read0[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            4'b0010: begin
                data_rdata = data_read1[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            4'b0100: begin
                data_rdata = data_read2[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            4'b1000: begin
                data_rdata = data_read3[cpu_word_off_reg * DATA_W +: DATA_W];
            end 
            default: begin
                data_rdata = 32'd0;
            end 
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
    // ---------------------------------------- data mem ----------------------------------------
    integer i;
    always @(posedge ACLK or negedge ARESETn) begin
        if (~ARESETn) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                valid[i] <= {NUM_WAYS{1'b0}};
            end
        end 
        else begin
            if (valid_we) begin
                valid[cpu_index_reg] <= valid[cpu_index_reg] | way_select;
            end 
        end 
    end

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

        .cpu_we     (1'b0),        
        .cpu_din    (32'd0),
        .cpu_wstrb  (4'd0),
        .cpu_offset (4'd0),

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

        .cpu_we     (1'b0),        
        .cpu_din    (32'd0),
        .cpu_wstrb  (4'd0),
        .cpu_offset (4'd0),

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

        .cpu_we     (1'b0),        
        .cpu_din    (32'd0),
        .cpu_wstrb  (4'd0),
        .cpu_offset (4'd0),

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

        .cpu_we     (1'b0),        
        .cpu_din    (32'd0),
        .cpu_wstrb  (4'd0),
        .cpu_offset (4'd0),

        .dout       (data_read3)        
    );

    // ---------------------------------------- xu ly address read ----------------------------------------

    assign oARADDR = {cpu_tag_reg, cpu_index_reg, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    assign oAWADDR = {cpu_tag_reg, cpu_index_reg, {WORD_OFF_W{1'b0}}, {BYTE_OFF_W{1'b0}}};
    // ---------------------------------------- cpu_tag mem ----------------------------------------
    wire [3:0] choosen_way;
    assign choosen_way = (any_hit) ? way_hit : way_select;

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way0 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[0]),
        .moesi_we           (1'b0),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read0)
    ); 

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way1 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[1]),
        .moesi_we           (1'b0),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read1)
    ); 

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way2 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[2]),
        .moesi_we           (1'b0),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read2)
    ); 

    tag_mem #(
        .NUM_SETS   (NUM_SETS),
        .TAG_W      (TAG_W   )
    ) tag_mem_way3 (
        .clk                (ACLK   ),
        .rst_n              (ARESETn),
        .tag_we             (tag_we & way_select[3]),
        .moesi_we           (1'b0),
        .read_index         (cpu_index    ),
        .write_index        (cpu_index_reg),
        .din_tag            (cpu_tag_reg  ),
        .dout_tag           (tag_read3)
    ); 
    // ---------------------------------------- policy replacement ----------------------------------------
    cache_replacement #(
        .N_WAYS     (NUM_WAYS),
        .N_LINES    (NUM_SETS)
    ) cache_replacement (
        .clk            (ACLK   ),
        .rst_n          (ARESETn),
        .we             (plru_we),
        .way_hit        ((plru_src) ? reg_way_select : way_hit),
        .addr           (cpu_index_reg),

        .way_select     (way_select)
        // .way_select_bin (way_select_bin )
    );
    // ---------------------------------------- controller ----------------------------------------
    icache_controller #(
        .DATA_W     (DATA_W),
        .ADDR_W     (ADDR_W),
        .ID_W       (ID_W),
        .USER_W     (USER_W),
        .STRB_W     (STRB_W),
        .BURST_LEN  (15)
    ) icache_controller(
        .clk            (ACLK),
        .rst_n          (ARESETn),

        .cpu_req        (reg_cpu_req),
        .hit            (any_hit),
        .plru_we        (plru_we),
        .plru_src       (plru_src),
        .tag_we         (tag_we),
        .valid_we       (valid_we),
        .refill_we      (refill_we),
        .cache_busy     (cache_busy),
        .cache_state    (cache_state),
        .burst_cnt      (burst_cnt),

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