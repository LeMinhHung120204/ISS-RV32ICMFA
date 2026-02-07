module dcache #(
    parameter ADDR_W        = 32
,   parameter DATA_W        = 32
,   parameter NUM_WAYS      = 4
,   parameter NUM_SETS      = 16

,   parameter DATA_START    = 32'h0000_4000
    
    // Derived parameters
,   parameter INDEX_W       = $clog2(NUM_SETS)
,   parameter WORD_OFF_W    = 4 // 16 words
,   parameter BYTE_OFF_W    = 2
,   parameter TAG_W         = ADDR_W - INDEX_W - WORD_OFF_W - BYTE_OFF_W
,   parameter CACHE_DATA_W  = (1 << WORD_OFF_W) * 32
)(
,   input   clk
,   input   rst_n

    // cache <-> CPU
,   input                       cpu_req
,   input                       cpu_we
,   input   [ADDR_W-1:0]        cpu_addr
,   input   [DATA_W-1:0]        cpu_din
,   input   [1:0]               cpu_size
    input                       cpu_amo,
    input                       cpu_lr,
    input                       cpu_sc,
,   output  reg [DATA_W-1:0]    data_rdata
,   output                      pipeline_stall
,   output                      raw_hazard

    // cache <-> L2
    // Request address
,   output                      o_l2_req_valid
,   input                       i_l2_req_ready
,   output  [1:0]               o_l2_req_cmd  // 0: Read, 1: WriteBack
,   output  [ADDR_W-1:0]        o_l2_req_addr

    // Request Moesi
,   input   [11:0]              i_l2_req_moesi_state
    // output  [INDEX_W-1:0]       o_l2_req_index,
    
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
    
,   output  reg                     o_snoop_complete
,   output  reg                     o_snoop_hit
,   output  reg                     o_snoop_dirty
,   output  reg [CACHE_DATA_W-1:0]  o_snoop_data
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
    
    wire                    s2_is_snoop;

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

    // ---------------------------------------- PIPELINE REGISTER (Stage 1 -> Stage 2) ----------------------------------------

    acc_cmp #(
        .ADDR_W     (ADDR_W), 
        .DATA_W     (DATA_W), 
        .NUM_SETS   (NUM_SETS)
    ) acc_cmp_inst (
        .clk            (clk), 
        .rst_n          (rst_n),
        .stall          (),
        .snoop_stall    (),
        .flush          (1'b0),

        // Inputs
        .s1_req         (cpu_req | i_snoop_valid),
        .s1_we          (cpu_we),
        .s1_size        (cpu_size),
        .s1_wdata       (cpu_din),
        .s1_tag         (s1_tag),
        .s1_index       (s1_index),
        .s1_word_off    (s1_word_off),
        .s1_byte_off    (s1_byte_off),
        
        .s1_is_snoop    (i_snoop_valid), 

        // Outputs (Stage 2)
        .s2_req         (s2_req),
        .s2_we          (s2_we),
        .s2_size        (s2_size),
        .s2_wdata       (s2_wdata),
        .s2_tag         (s2_tag),
        .s2_index       (s2_index),
        .s2_word_off    (s2_word_off),
        .s2_byte_off    (s2_byte_off),

        .s2_is_snoop    (s2_is_snoop)
    );

    
endmodule 