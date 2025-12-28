`timescale 1ns/1ps
module DataMem_wrapper #(
    parameter WIDTH_ADDR    = 8,
    parameter ID_W          = 2,
    parameter DATA_W        = 32,
    parameter STRB_W        = DATA_W / 8
)(
    input   ACLK,
    input   ARESETn,

    // AW Channel
    input [ID_W-1:0]    i_axi_awid,
    input [DATA_W-1:0]  i_axi_awaddr,
    input [7:0]         i_axi_awlen,
    input [2:0]         i_axi_awsize,
    input [1:0]         i_axi_awburst,
    input               i_axi_awvalid,
    output              0_axi_awready,
    
    // W Channel
    output              o_axi_wready,
    input [DATA_W-1:0]  i_axi_wdata,
    input [STRB_W-1:0]  i_axi_wstrb,
    input               i_axi_wlast,
    input               i_axi_wvalid,

    // B Channel
    output [ID_W-1:0]   o_axi_bid,
    output [1:0]        o_axi_bresp,
    output              o_axi_bvalid,
    input               i_axi_bready,

    // AR Channel
    output              o_axi_arready,
    input [ID_W-1:0]    i_axi_arid,
    input [DATA_W-1:0]  i_axi_araddr,
    input [7:0]         i_axi_arlen,
    input [2:0]         i_axi_arsize,
    input [1:0]         i_axi_arburst,
    input               i_axi_arvalid,

    // R Channel
    output [ID_W-1:0]   o_axi_rid,
    output [DATA_W-1:0] o_axi_rdata,
    output [1:0]        o_axi_rresp,
    output              o_axi_rlast,
    output              o_axi_rvalid,
    input               i_axi_rready
);  
    // ---------------------------------------- FIFO Width Definitions ----------------------------------------
    localparam FF_AW_W = DATA_W + ID_W + 8 + 3 + 2;     // AW: ADDR + ID + LEN + SIZE + BURST
    localparam FF_W_W  = DATA_W + ID_W + STRB_W + 1;    // W: DATA + ID + STRB + LAST
    localparam FF_B_W  = ID_W + 2;                      // B: ID + RESP
    localparam FF_AR_W = DATA_W + ID_W + 8 + 3 + 2;     // AR: ADDR + ID + LEN + SIZE + BURST
    localparam FF_R_W  = DATA_W + ID_W + 2 + 1;         // R: DATA + ID + RESP + LAST

    // ---------------------------------------- FIFO Signals ----------------------------------------
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
    
    // Signals from control modules
    wire                    ctrl_w_ready;
    wire                    ctrl_r_valid;
    wire                    ctrl_r_last; 
    
    // ---------------------------------------- Unpack FIFOs (Tach day) ----------------------------------------
    // AW FIFO
    wire [DATA_W-1:0] fifo_awaddr  = fifo_aw_dout[FF_AW_W-1 -: DATA_W];
    wire [ID_W-1:0]   fifo_awid    = fifo_aw_dout[FF_AW_W-1 - DATA_W -: ID_W];
    wire [7:0]        fifo_awlen   = fifo_aw_dout[FF_AW_W-1 - DATA_W - ID_W -: 8];
    wire [2:0]        fifo_awsize  = fifo_aw_dout[FF_AW_W-1 - DATA_W - ID_W - 8 -: 3];
    wire [1:0]        fifo_awburst = fifo_aw_dout[FF_AW_W-1 - DATA_W - ID_W - 8 - 3 -: 2];

    // W FIFO
    wire [DATA_W-1:0] fifo_wdata   = fifo_w_dout[FF_W_W-1 -: DATA_W];
    // wire [ID_W-1:0] fifo_wid    (Not used in AXI4 write data channel usually)
    wire [STRB_W-1:0] fifo_wstrb   = fifo_w_dout[FF_W_W-1 - DATA_W - ID_W -: STRB_W];
    wire              fifo_wlast   = fifo_w_dout[0];

    // AR FIFO
    wire [DATA_W-1:0] fifo_araddr  = fifo_ar_dout[FF_AR_W-1 -: DATA_W];
    wire [ID_W-1:0]   fifo_arid    = fifo_ar_dout[FF_AR_W-1 - DATA_W -: ID_W];
    wire [7:0]        fifo_arlen   = fifo_ar_dout[FF_AR_W-1 - DATA_W - ID_W -: 8];
    wire [2:0]        fifo_arsize  = fifo_ar_dout[FF_AR_W-1 - DATA_W - ID_W - 8 -: 3];
    wire [1:0]        fifo_arburst = fifo_ar_dout[FF_AR_W-1 - DATA_W - ID_W - 8 - 3 -: 2];
    
    // ---------------------------------------- LOGIC dieu khien ----------------------------------------

    // AXI OUTPUT ASSIGNMENTS
    assign 0_axi_awready = ~fifo_aw_full;
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
    
    // ---------------------------------------- WRITE PATH ----------------------------------------
    assign fifo_w_pop       = core_write_en; 
    wire write_burst_done   = core_write_en && fifo_wlast;

    // Push B_FIFO: Khi burst write xong.
    assign fifo_b_push      = write_burst_done & ~fifo_b_full;
    
    // Pop AW_FIFO: CHỈ POP khi đã push xong Response vào B_FIFO
    // Lý do: Cần giữ AWID ở đầu ra FIFO cho đến giây phút cuối cùng để đưa vào B_FIFO
    assign fifo_aw_pop      = fifo_b_push; 
    assign fifo_b_pop       = i_axi_bready & ~fifo_b_empty;


    // ---------------------------------------- READ PATH ----------------------------------------
    assign fifo_r_push   = ctrl_r_valid & ~fifo_r_full;

    // Pop AR_FIFO: CHỈ POP khi đã push beat CUỐI CÙNG (rlast) vào R_FIFO
    // Lý do: Cần giữ ARID để gắn vào mọi beat dữ liệu trả về
    assign fifo_ar_pop   = fifo_r_push && ctrl_r_last;
    assign fifo_r_pop    = i_axi_rready & ~fifo_r_empty;


    // ----------------------------------------- INSTANTIATE MODULES -----------------------------------------
    control_write #(
        .DATA_W (DATA_W)
    ) u_control_write (
        .clk        (ACLK),
        .rst_n      (ARESETn),

        // AW Channel
        .awvalid    (~fifo_aw_empty), // bao valid khi fifo co data
        .awready    (control_awready),
        .awburst    (fifo_awburst),
        .awsize     (fifo_awsize),
        .awlen      (fifo_awlen),
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
        .arsize     (fifo_arsize),
        .arlen      (fifo_arlen),
        .araddr     (fifo_araddr),

        // R Channel Control
        .rready     (~fifo_r_full), // R_FIFO con cha thi cu doc
        .rlast      (ctrl_r_last), 
        .rvalid     (ctrl_r_valid),
        
        .r_addr     (cnt_addr_read),
        .read_en    (core_read_en)          
    );

    ram #(
        .ADDR_W (WIDTH_ADDR),
        .DATA_W (DATA_W)
    ) u_DataMem (
        .clk        (ACLK),
        .rst_n      (ARESETn),
        
        // Port A: Write
        .we         (core_write_en),
        .w_addr     (cnt_addr_write[WIDTH_ADDR-1:0]), 
        .w_data     (fifo_wdata),

        // Port B: Read
        .re         (core_read_en),   
        .r_addr     (cnt_addr_read[WIDTH_ADDR-1:0]),
        .r_data     (ram_r_data)
    );

    // ----------------------------------------- INSTANTIATE FIFOs -----------------------------------------
    FIFO #(
        .DATA_W (FF_AW_W), 
        .DEPTH  (4)
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
        .DEPTH  (16)
    ) u_W_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_w_push), 
        .pop    (fifo_w_pop),
        .din    ({i_axi_wdata, i_axi_wid, i_axi_wstrb, i_axi_wlast}),
        .empty  (fifo_w_empty), 
        .full   (fifo_w_full), 
        .dout   (fifo_w_dout)
    );

    FIFO #(
        .DATA_W (FF_B_W), 
        .DEPTH  (4)
    ) u_B_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_b_push), 
        .pop    (fifo_b_pop),
        // Lay ID tu AW FIFO (Vi luc nay AW FIFO chua pop)
        .din    ({fifo_awid, 2'b00}),
        .empty  (fifo_b_empty), 
        .full   (fifo_b_full), 
        .dout   (fifo_b_dout)
    );

    FIFO #(
        .DATA_W (FF_AR_W), 
        .DEPTH  (4)
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
        .DEPTH  (16)
    ) u_R_FIFO (
        .clk    (ACLK), 
        .rst_n  (ARESETn),
        .push   (fifo_r_push), 
        .pop    (fifo_r_pop),
        .din    ({ram_r_data, fifo_arid, 2'b00, ctrl_r_last}),
        .empty  (fifo_r_empty), 
        .full   (fifo_r_full), 
        .dout   (fifo_r_dout)
    );

endmodule