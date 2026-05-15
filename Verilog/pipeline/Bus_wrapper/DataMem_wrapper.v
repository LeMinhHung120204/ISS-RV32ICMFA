`timescale 1ns/1ps
// from Lee Min Hunz with luv
// ============================================================================
// DataMem Wrapper - AXI4 Slave Memory Controller
// ============================================================================
// Provides AXI4 interface to RAM with FIFO buffering for all channels.
// Supports burst read/write with flow control.
// ============================================================================
module DataMem_wrapper #(
    parameter DEPTH         = 256           // Number of RAM entries (must be power of 2)
,   parameter RAM_ADDR_W    = $clog2(DEPTH) // Address width for RAM
,   parameter ID_W          = 2
,   parameter DATA_W        = 32
,   parameter ADDR_W        = 32
,   parameter RESET_VALUE   = 0
,   parameter STRB_W        = DATA_W / 8
,   parameter INIT_FILE_A   = ""
,   parameter INIT_FILE_B   = ""
,   parameter INIT_IDX_A    = 0
,   parameter INIT_IDX_B    = 0
)(
    input   ACLK
,   input   ARESETn

    // AW Channel
,   input [ID_W-1:0]    i_axi_awid
,   input [ADDR_W-1:0]  i_axi_awaddr
,   input [7:0]         i_axi_awlen
,   input [2:0]         i_axi_awsize
,   input [1:0]         i_axi_awburst
,   input               i_axi_awvalid
,   output              o_axi_awready
    
    // W Channel
,   output              o_axi_wready
,   input [DATA_W-1:0]  i_axi_wdata
,   input [STRB_W-1:0]  i_axi_wstrb
,   input               i_axi_wlast
,   input               i_axi_wvalid

    // B Channel
,   output [ID_W-1:0]   o_axi_bid
,   output [1:0]        o_axi_bresp
,   output              o_axi_bvalid
,   input               i_axi_bready

    // AR Channel
,   output              o_axi_arready
,   input [ID_W-1:0]    i_axi_arid
,   input [ADDR_W-1:0]  i_axi_araddr
,   input [7:0]         i_axi_arlen
,   input [2:0]         i_axi_arsize
,   input [1:0]         i_axi_arburst
,   input               i_axi_arvalid

    // R Channel
,   output [ID_W-1:0]   o_axi_rid
,   output [DATA_W-1:0] o_axi_rdata
,   output [1:0]        o_axi_rresp
,   output              o_axi_rlast
,   output              o_axi_rvalid
,   input               i_axi_rready
);  
    // ================================================================
    // FIFO WIDTH DEFINITIONS
    // ================================================================
    localparam FF_AW_W = DATA_W + ID_W + 8 + 3 + 2;     // AW: ADDR + ID + LEN + SIZE + BURST
    localparam FF_W_W  = DATA_W + STRB_W + 1;           // W: DATA + STRB + LAST
    localparam FF_B_W  = ID_W + 2;                      // B: ID + RESP
    localparam FF_AR_W = DATA_W + ID_W + 8 + 3 + 2;     // AR: ADDR + ID + LEN + SIZE + BURST
    localparam FF_R_W  = DATA_W + ID_W + 2 + 1;         // R: DATA + ID + RESP + LAST

    // ================================================================
    // FIFO SIGNALS
    // ================================================================
    wire [FF_AW_W - 1:0]    fifo_aw_dout;
    wire [FF_W_W - 1:0]     fifo_w_dout; 
    wire [FF_B_W - 1:0]     fifo_b_dout; 
    wire [FF_AR_W - 1:0]    fifo_ar_dout;
    wire [FF_R_W - 1:0]     fifo_r_dout;
    
    wire                    fifo_aw_full, fifo_w_full, fifo_b_full, fifo_ar_full, fifo_r_full; 
    wire                    fifo_aw_empty, fifo_w_empty, fifo_b_empty, fifo_ar_empty, fifo_r_empty;
    
    wire                    fifo_aw_pop, fifo_w_pop, fifo_b_pop, fifo_ar_pop, fifo_r_pop;
    wire                    fifo_aw_push, fifo_w_push, fifo_b_push, fifo_ar_push, fifo_r_push;
    
    // Internal Control Signals
    wire                    control_awready, control_arready;
    wire                    core_write_en, core_read_en;
    wire [DATA_W-1:0]       cnt_addr_write, cnt_addr_read;
    wire [DATA_W-1:0]       ram_r_data;
    wire                    rvalid_from_mem;
    wire                    last_data_from_mem;
    
    // Signals from control modules
    wire                    ctrl_w_ready;
    // wire                    ctrl_r_last; 
    
    // ================================================================
    // UNPACK FIFOs
    // ================================================================
    // AW FIFO
    wire [DATA_W-1:0] fifo_awaddr  = fifo_aw_dout[FF_AW_W-1 -: DATA_W];
    wire [ID_W-1:0]   fifo_awid    = fifo_aw_dout[FF_AW_W-1 - DATA_W -: ID_W];
    // wire [7:0]        fifo_awlen   = fifo_aw_dout[FF_AW_W-1 - DATA_W - ID_W -: 8];
    // wire [2:0]        fifo_awsize  = fifo_aw_dout[FF_AW_W-1 - DATA_W - ID_W - 8 -: 3];
    wire [1:0]        fifo_awburst = fifo_aw_dout[FF_AW_W-1 - DATA_W - ID_W - 8 - 3 -: 2];

    // W FIFO
    wire [DATA_W-1:0] fifo_wdata   = fifo_w_dout[FF_W_W-1 -: DATA_W];
    wire [STRB_W-1:0] fifo_wstrb   = fifo_w_dout[FF_W_W-1 - DATA_W  -: STRB_W]; // chua dung
    wire              fifo_wlast   = fifo_w_dout[0];

    // AR FIFO
    wire [DATA_W-1:0] fifo_araddr  = fifo_ar_dout[FF_AR_W-1 -: DATA_W];
    wire [ID_W-1:0]   fifo_arid    = fifo_ar_dout[FF_AR_W-1 - DATA_W -: ID_W];
    wire [7:0]        fifo_arlen   = fifo_ar_dout[FF_AR_W-1 - DATA_W - ID_W -: 8];
    wire [2:0]        fifo_arsize  = fifo_ar_dout[FF_AR_W-1 - DATA_W - ID_W - 8 -: 3];
    wire [1:0]        fifo_arburst = fifo_ar_dout[FF_AR_W-1 - DATA_W - ID_W - 8 - 3 -: 2];
    
    // ================================================================
    // CONTROL LOGIC
    // ================================================================

    // AXI OUTPUT ASSIGNMENTS
    assign o_axi_awready = ~fifo_aw_full;
    assign o_axi_wready  = ~fifo_w_full;
    assign o_axi_arready = ~fifo_ar_full;

    // B Channel Output
    assign o_axi_bvalid  = ~fifo_b_empty;
    assign o_axi_bid     = fifo_b_dout[FF_B_W-1 -: ID_W];
    assign o_axi_bresp   = fifo_b_dout[1:0];

    // R Channel Output
    assign o_axi_rvalid  = ~fifo_r_empty;
    assign o_axi_rdata   = fifo_r_dout[FF_R_W-1 -: DATA_W];
    assign o_axi_rid     = fifo_r_dout[FF_R_W-1 - DATA_W -: ID_W];
    assign o_axi_rresp   = fifo_r_dout[2:1];
    assign o_axi_rlast   = fifo_r_dout[0];

    // FIFO PUSH CONTROL (AXI Inputs -> FIFOs)
    assign fifo_aw_push  = ~fifo_aw_full & i_axi_awvalid;
    assign fifo_w_push   = ~fifo_w_full  & i_axi_wvalid;
    assign fifo_ar_push  = ~fifo_ar_full & i_axi_arvalid;
    
    // ================================================================
    // WRITE PATH - AW/W -> RAM -> B
    // ================================================================
    assign fifo_w_pop       = core_write_en & ctrl_w_ready; 
    wire write_burst_done   = core_write_en && fifo_wlast;

    // Push B response when burst completes
    assign fifo_b_push      = write_burst_done & ~fifo_b_full;
    
    // Pop AW after B response pushed (need AWID for B channel)
    assign fifo_aw_pop      = fifo_b_push; 
    assign fifo_b_pop       = i_axi_bready & ~fifo_b_empty;


    // ================================================================
    // READ PATH - AR -> RAM -> R
    // ================================================================
    assign fifo_r_push   = rvalid_from_mem & ~fifo_r_full;

    // Pop AR after last beat pushed to R (need ARID for each beat)
    assign fifo_ar_pop   = fifo_r_push && last_data_from_mem;
    assign fifo_r_pop    = i_axi_rready & ~fifo_r_empty;

    // ================================================================
    // MODULE INSTANTIATIONS
    // ================================================================
    control_write #(
        .DATA_W (DATA_W)
    ) u_control_write (
        .clk        (ACLK),
        .rst_n      (ARESETn),

        // AW Channel
        .awvalid    (~fifo_aw_empty), // bao valid khi fifo co data
        .awready    (control_awready),
        .awburst    (fifo_awburst),
        // .awsize     (fifo_awsize),
        // .awlen      (fifo_awlen),
        .awaddr     (fifo_awaddr),

        // W Channel 
        .wvalid     (~fifo_w_empty), // bao valid khi fifo co data
        .wlast      (fifo_wlast),
        .wready     (ctrl_w_ready),
        
        // Memory Interface
        .w_addr     (cnt_addr_write),
        .write_en   (core_write_en)          
    );

    control_read #(
        .DATA_W (DATA_W)
    ) u_control_read (
        .clk        (ACLK),
        .rst_n      (ARESETn),

        // AR Channel Info
        .arvalid    (~fifo_ar_empty),
        .arready    (control_arready),
        .arburst    (fifo_arburst),
        // .arsize     (fifo_arsize),
        .arlen      (fifo_arlen),
        .araddr     (fifo_araddr),

        .fifo_r_push_able   (~fifo_r_full),     // Can push to R_FIFO
        // .fifo_r_pop_able    (~fifo_r_empty),    // Can pop from R_FIFO
        
        // Memory Interface
        .fifo_ar_full       (fifo_ar_full),
        .r_addr             (cnt_addr_read),
        .read_en            (core_read_en),
        // .rvalid_from_mem    (rvalid_from_mem),
        .last_data_from_mem (last_data_from_mem)
    );

    ram #(
        .ADDR_W         (RAM_ADDR_W)
    ,   .DATA_W         (DATA_W)
    ,   .RESET_VALUE    (RESET_VALUE)
    ,   .INIT_FILE_A    (INIT_FILE_A)
    ,   .INIT_FILE_B    (INIT_FILE_B)
    ,   .INIT_IDX_A     (INIT_IDX_A)
    ,   .INIT_IDX_B     (INIT_IDX_B)
    ) u_DataMem (
        .clk        (ACLK),
        // .rst_n      (ARESETn),
        
        // Port A: Write
        .we         (core_write_en),
        .w_addr     (cnt_addr_write[RAM_ADDR_W-1:0]), 
        .w_data     (fifo_wdata),

        // Port B: Read
        .re         (core_read_en),   
        .r_addr     (cnt_addr_read[RAM_ADDR_W-1:0]),
        .r_data     (ram_r_data),
        .valid      (rvalid_from_mem)
    );

    // ================================================================
    // FIFO INSTANTIATIONS
    // ================================================================
    FIFO #(
        .DATA_W (FF_AW_W), 
        .DEPTH  (DEPTH)
    ) u_AW_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_aw_push), 
        .pop    (fifo_aw_pop),
        .din    ({i_axi_awaddr, i_axi_awid, i_axi_awlen, i_axi_awsize, i_axi_awburst}),
        .empty  (fifo_aw_empty), 
        .full   (fifo_aw_full), 
        .dout   (fifo_aw_dout)
    );

    FIFO #(
        .DATA_W (FF_W_W), 
        .DEPTH  (DEPTH)
    ) u_W_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_w_push), 
        .pop    (fifo_w_pop),
        .din    ({i_axi_wdata, i_axi_wstrb, i_axi_wlast}),
        .empty  (fifo_w_empty), 
        .full   (fifo_w_full), 
        .dout   (fifo_w_dout)
    );

    FIFO #(
        .DATA_W (FF_B_W), 
        .DEPTH  (DEPTH)
    ) u_B_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_b_push), 
        .pop    (fifo_b_pop),
        // Get ID from AW FIFO (not popped yet)
        .din    ({fifo_awid, 2'b00}),
        .empty  (fifo_b_empty), 
        .full   (fifo_b_full), 
        .dout   (fifo_b_dout)
    );

    FIFO #(
        .DATA_W (FF_AR_W), 
        .DEPTH  (DEPTH)
    ) u_AR_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_ar_push), 
        .pop    (fifo_ar_pop),
        .din    ({i_axi_araddr, i_axi_arid, i_axi_arlen, i_axi_arsize, i_axi_arburst}),
        .empty  (fifo_ar_empty), 
        .full   (fifo_ar_full), 
        .dout   (fifo_ar_dout)
    );

    FIFO #(
        .DATA_W (FF_R_W), 
        .DEPTH  (DEPTH)
    ) u_R_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_r_push), 
        // .push   (reg_fifo_r_push), 
        .pop    (fifo_r_pop),
        .din    ({ram_r_data, fifo_arid, 2'b00, last_data_from_mem}),
        .empty  (fifo_r_empty), 
        .full   (fifo_r_full), 
        .dout   (fifo_r_dout)
    );

endmodule