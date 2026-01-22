`timescale 1ns/1ps
module ace_interconnect #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32, // Cache Line Width (Wide Bus)
    parameter ID_W   = 2
)(
    input clk, rst_n,

    // ================= CLIENT 0 (CORE A) =================
    // AR Channel
    input  [ADDR_W-1:0] s0_axi_araddr,
    input  [3:0]        s0_axi_arsnoop,
    input               s0_axi_arvalid,
    output reg          s0_axi_arready,
    // AW/W/B Channel (Write)
    input  [ADDR_W-1:0] s0_axi_awaddr,
    input               s0_axi_awvalid,
    output reg          s0_axi_awready,

    input  [DATA_W-1:0] s0_axi_wdata,
    input               s0_axi_wvalid,
    output reg          s0_axi_wready,

    output reg          s0_axi_bvalid,
    output reg [1:0]    s0_axi_bresp,
    input               s0_axi_bready,
    
    // R Channel
    output reg [DATA_W-1:0] s0_axi_rdata,
    output reg              s0_axi_rvalid,
    output reg              s0_axi_rlast,
    input                   s0_axi_rready,

    // AC Channel (Snoop Input to Core A)
    output reg [ADDR_W-1:0] s0_ace_acaddr,
    output reg [3:0]        s0_ace_acsnoop,
    output reg              s0_ace_acvalid,
    input                   s0_ace_acready,

    // CR/CD Channel (Snoop Response from Core A)
    input               s0_ace_crvalid,
    input  [4:0]        s0_ace_crresp,
    input  [DATA_W-1:0] s0_ace_cddata,
    input               s0_ace_cdvalid,

    // ================= CLIENT 1 (CORE B) =================
    input  [ADDR_W-1:0] s1_axi_araddr,
    input  [3:0]        s1_axi_arsnoop,
    input               s1_axi_arvalid,
    output reg          s1_axi_arready,
    // AW/W/B Channel (Write)
    input  [ADDR_W-1:0] s1_axi_awaddr,
    input               s1_axi_awvalid,
    output reg          s1_axi_awready,

    input  [DATA_W-1:0] s1_axi_wdata,
    input               s1_axi_wvalid,
    output reg          s1_axi_wready,

    output reg          s1_axi_bvalid,
    output reg [1:0]    s1_axi_bresp,
    input               s1_axi_bready,
    
    output reg [DATA_W-1:0] s1_axi_rdata,
    output reg              s1_axi_rvalid,
    output reg              s1_axi_rlast,
    input                   s1_axi_rready,

    output reg [ADDR_W-1:0] s1_ace_acaddr,
    output reg [3:0]        s1_ace_acsnoop,
    output reg              s1_ace_acvalid,
    input                   s1_ace_acready,

    input               s1_ace_crvalid,
    input  [4:0]        s1_ace_crresp,
    input  [DATA_W-1:0] s1_ace_cddata,
    input               s1_ace_cdvalid,

    // ================= MASTER PORT (TO EXTERNAL MEMORY) =================
    output [ADDR_W-1:0] mem_araddr,
    output              mem_arvalid,
    input               mem_arready,

    input  [DATA_W-1:0] mem_rdata,
    input               mem_rvalid,
    input               mem_rlast,
    output              mem_rready,

    // Write channels to memory
    output [ADDR_W-1:0] mem_awaddr,
    output              mem_awvalid,
    input               mem_awready,

    output [DATA_W-1:0] mem_wdata,
    output              mem_wvalid,
    input               mem_wready,

    input               mem_bvalid,
    input  [1:0]        mem_bresp,
    output              mem_bready
);
    localparam IDLE             = 3'd0;
    localparam SNOOP_REQ        = 3'd1; // Gui lenh snoop sang core kia
    localparam WAIT_CR          = 3'd2; // doi core kia check tag xong
    localparam MEM_REQ          = 3'd3;
    localparam DATA_MEM         = 3'd4; // Miss snoop -> Lay data tu mem
    localparam DATA_SNOOP       = 3'd5; // Hit snoop -> Lay data tu Core kia
    localparam MEM_WR_REQ       = 3'd6; // Write request to mem
    localparam DATA_WR_SNOOP    = 3'd7; // Write - obtain data from snoop

    reg [2:0] state, next_state;
    reg grant_s0;

    reg is_write_request;

    // --------------------------------------------------------
    // Internal wires for arbiter + mux
    wire r_grant0, r_grant1;
    wire w_grant0, w_grant1;

    // Master-mux wires (slave side = memory)
    wire [ADDR_W-1:0]   mux_s_araddr;
    wire                mux_s_arvalid;
    wire                mux_s_arready;
    wire [DATA_W-1:0]   mux_s_rdata;
    wire                mux_s_rvalid;
    wire                mux_s_rlast;
    wire                mux_s_rready;

    wire [ADDR_W-1:0]   mux_s_awaddr;
    wire                mux_s_awvalid;
    wire                mux_s_awready;
    wire [DATA_W-1:0]   mux_s_wdata;
    wire                mux_s_wvalid;
    wire                mux_s_wready;
    wire                mux_s_bvalid;
    wire [1:0]          mux_s_bresp;
    wire                mux_s_bready;

    // Master-side wires from mux to clients
    wire                mux_m0_arready, mux_m1_arready;
    wire [DATA_W-1:0]   mux_m0_rdata, mux_m1_rdata;
    wire                mux_m0_rvalid, mux_m1_rvalid;
    wire                mux_m0_rlast, mux_m1_rlast;
    wire                mux_m0_awready, mux_m1_awready;
    wire                mux_m0_wready, mux_m1_wready;
    wire                mux_m0_bvalid, mux_m1_bvalid;
    wire [1:0]          mux_m0_bresp, mux_m1_bresp;

    // Internal write-data sources (allow snoop -> write path)
    wire [DATA_W-1:0]   m0_wdata_int, m1_wdata_int;
    wire                m0_wvalid_int, m1_wvalid_int;

    // Intermediate wires to avoid expressions inside module instantiations
    wire grant_s1;
    wire arb_m0_arvalid, arb_m1_arvalid;
    wire arb_m0_awvalid, arb_m1_awvalid;
    wire arb_m0_wvalid,  arb_m1_wvalid;

    assign grant_s1         = ~grant_s0;
    assign arb_m0_arvalid   = s0_axi_arvalid & grant_s0;
    assign arb_m1_arvalid   = s1_axi_arvalid & grant_s1;
    assign arb_m0_awvalid   = s0_axi_awvalid & grant_s0;
    assign arb_m1_awvalid   = s1_axi_awvalid & grant_s1;
    assign arb_m0_wvalid    = s0_axi_wvalid  & grant_s0;
    assign arb_m1_wvalid    = s1_axi_wvalid  & grant_s1;

    // -------------------------------------------------------- ARBITER & STATE MACHINE --------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state           <= IDLE;
            grant_s0        <= 1'b1;
        end 
        else begin
            state <= next_state;
            
            case(state)
                IDLE: begin
                    // Choose grant based on incoming AR or AW (reads or writes)
                    if (s0_axi_arvalid || s0_axi_awvalid) begin
                        grant_s0 <= 1'b1;
                    end 
                    else if (s1_axi_arvalid || s1_axi_awvalid) begin
                        grant_s0 <= 1'b0;
                    end
                    // Capture whether incoming request is a write
                    if (s0_axi_awvalid || s1_axi_awvalid) begin
                        is_write_request <= s0_axi_awvalid; // if core0 AW valid then true else core1
                    end 
                    else begin
                        is_write_request <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Instantiate read arbiter (mask ARVALID by grant_s0 to enforce FCFS selection)
    AXI_Arbiter_R u_arb_r (
        .ACLK       (clk),
        .ARESETn    (rst_n),

        .m0_ARVALID (arb_m0_arvalid),
        .m0_RREADY  (s0_axi_rready),

        .m1_ARVALID (arb_m1_arvalid),
        .m1_RREADY  (s1_axi_rready),

        .s_RVALID   (mem_rvalid),
        .s_RLAST    (mem_rlast),
        
        .m0_rgrnt   (r_grant0),
        .m1_rgrnt   (r_grant1)
    );

    // Instantiate write arbiter (mask AW/W by grant_s0)
    AXI_Arbiter_W u_arb_w (
        .ACLK       (clk),
        .ARESETn    (rst_n),
        
        .m0_AWVALID (arb_m0_awvalid),
        .m0_WVALID  (arb_m0_wvalid),
        .m0_BREADY  (s0_axi_bready),

        .m1_AWVALID (arb_m1_awvalid),
        .m1_WVALID  (arb_m1_wvalid),
        .m1_BREADY  (s1_axi_bready),

        .s_BVALID   (mem_bvalid),

        .m0_wgrnt   (w_grant0),
        .m1_wgrnt   (w_grant1)
    );

    // Prepare write-data sources: by default take client W, but in DATA_WR_SNOOP override to snoop CD
    assign m0_wdata_int     = s0_axi_wdata;
    assign m0_wvalid_int    = s0_axi_wvalid & grant_s0;

    assign m1_wdata_int     = s1_axi_wdata;
    assign m1_wvalid_int    = s1_axi_wvalid & ~grant_s0;

    // Instantiate master muxes
    AXI_Master_Mux_R #(
        .ADDR_W(ADDR_W), 
        .DATA_W(DATA_W)
    ) u_mux_r (
        .clk        (clk), 
        .m0_araddr  (s0_axi_araddr),
        .m0_arvalid (arb_m0_arvalid),
        .m0_arready (mux_m0_arready),
        .m0_rdata   (mux_m0_rdata),
        .m0_rvalid  (mux_m0_rvalid),
        .m0_rlast   (mux_m0_rlast),
        .m0_rready  (s0_axi_rready),

        .m1_araddr  (s1_axi_araddr),
        .m1_arvalid (arb_m1_arvalid),
        .m1_arready (mux_m1_arready),
        .m1_rdata   (mux_m1_rdata),
        .m1_rvalid  (mux_m1_rvalid),
        .m1_rlast   (mux_m1_rlast),
        .m1_rready  (s1_axi_rready),

        .s_araddr   (mux_s_araddr),
        .s_arvalid  (mux_s_arvalid),
        .s_arready  (mem_arready),
        .s_rdata    (mem_rdata),
        .s_rvalid   (mem_rvalid),
        .s_rlast    (mem_rlast),
        .s_rready   (mux_s_rready),

        .m0_rgrnt   (r_grant0),
        .m1_rgrnt   (r_grant1)
    );

    AXI_Master_Mux_W #(
        .ADDR_W(ADDR_W), 
        .DATA_W(DATA_W)
    ) u_mux_w (
        .clk        (clk),
        .m0_awaddr  (s0_axi_awaddr),
        .m0_awvalid (arb_m0_awvalid),
        .m0_awready (mux_m0_awready),
        .m0_wdata   (m0_wdata_int),
        .m0_wvalid  (m0_wvalid_int),
        .m0_wready  (mux_m0_wready),
        .m0_bvalid  (mux_m0_bvalid),
        .m0_bresp   (mux_m0_bresp),
        .m0_bready  (s0_axi_bready),

        .m1_awaddr  (s1_axi_awaddr),
        .m1_awvalid (arb_m1_awvalid),
        .m1_awready (mux_m1_awready),
        .m1_wdata   (m1_wdata_int),
        .m1_wvalid  (m1_wvalid_int),
        .m1_wready  (mux_m1_wready),
        .m1_bvalid  (mux_m1_bvalid),
        .m1_bresp   (mux_m1_bresp),
        .m1_bready  (s1_axi_bready),

        .s_awaddr   (mux_s_awaddr),
        .s_awvalid  (mux_s_awvalid),
        .s_awready  (mem_awready),
        .s_wdata    (mux_s_wdata),
        .s_wvalid   (mux_s_wvalid),
        .s_wready   (mem_wready),
        .s_bvalid   (mem_bvalid),
        .s_bresp    (mem_bresp),
        .s_bready   (mux_s_bready),

        .m0_wgrnt   (w_grant0),
        .m1_wgrnt   (w_grant1)
    );

    // Connect mux slave-side nets to top-level memory signals
    assign mem_araddr  = mux_s_araddr;
    assign mem_arvalid = mux_s_arvalid;
    assign mem_rready  = mux_s_rready;
    assign mem_awaddr  = mux_s_awaddr;
    assign mem_awvalid = mux_s_awvalid;
    assign mem_wdata   = mux_s_wdata;
    assign mem_wvalid  = mux_s_wvalid;
    assign mem_bready  = mux_s_bready;

    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if (s0_axi_arvalid || s1_axi_arvalid || s0_axi_awvalid || s1_axi_awvalid) begin
                    next_state = SNOOP_REQ;
                end 
            end

            SNOOP_REQ: begin
                // Buoc 1: Chi gui Snoop sang Core kia
                if (grant_s0) begin
                    if (s1_ace_acready) begin
                        next_state = WAIT_CR;
                    end 
                end 
                else begin
                    if (s0_ace_acready) begin 
                        next_state = WAIT_CR;
                    end 
                end
            end

            // WAIT_CR: begin
            //     // Buoc 2: Doi phan hoi
            //     if (grant_s0 && s1_ace_crvalid) begin
            //         // Neu peer has data (CRRESP.dt or CRRESP.pd) -> Lay data từ Core B
            //         if (s1_ace_crresp[0] || s1_ace_crresp[2]) begin
            //             // If original request was write, go to write-snoop data state
            //             if (is_write_request) begin 
            //                 next_state = DATA_WR_SNOOP;
            //             end 
            //             else begin 
            //                 next_state = DATA_SNOOP;
            //             end 
            //         end 
            //         // Neu MISS/CLEAN -> doc tu mem
            //         else begin    
            //             if (is_write_request) begin
            //                 next_state = MEM_WR_REQ; 
            //             end 
            //             else begin
            //                 next_state = MEM_REQ; 
            //             end
            //         end 
            //     end 
            //     else if (!grant_s0 && s0_ace_crvalid) begin
            //         if (s0_ace_crresp[0] || s0_ace_crresp[2]) begin
            //             if (is_write_request) begin
            //                 next_state = DATA_WR_SNOOP;
            //             end 
            //             else begin
            //                 next_state = DATA_SNOOP;
            //             end
            //         end 
            //         else begin                  
            //             if (is_write_request) begin
            //                 next_state = MEM_WR_REQ;
            //             end 
            //             else begin
            //                 next_state = MEM_REQ;
            //             end
            //         end 
            //     end
            // end

            // testing without snoop hit
            WAIT_CR: begin
                // Buoc 2: Doi phan hoi
                if (grant_s0 && s1_ace_crvalid) begin       
                    if (is_write_request) begin
                        next_state = MEM_WR_REQ; 
                    end 
                    else begin
                        next_state = MEM_REQ; 
                    end
                
                end 
                else if (!grant_s0 && s0_ace_crvalid) begin      
                    if (is_write_request) begin
                        next_state = MEM_WR_REQ;
                    end 
                    else begin
                        next_state = MEM_REQ;
                    end
                 
                end
            end
            
            MEM_REQ: begin
                // Buoc 3: Gui request xuong memory
                if (mem_arready) begin
                    next_state = DATA_MEM;
                end
            end

            MEM_WR_REQ: begin
                if (grant_s0) begin
                    // requester is master 0, CD comes from core1
                    s0_axi_rvalid   = s1_ace_cdvalid;
                    s0_axi_rdata    = s1_ace_cddata;
                    s0_axi_rlast    = 1'b1;
                    s0_axi_bvalid   = s1_ace_cdvalid;
                    s0_axi_bresp    = 2'b00;
                    if (s1_ace_cdvalid) begin
                        next_state = IDLE; // done, no mem write
                    end
                    else begin
                        next_state = DATA_WR_SNOOP;
                    end
                end
                else begin
                    // requester is master 1, CD comes from core0
                    s1_axi_rvalid   = s0_ace_cdvalid;
                    s1_axi_rdata    = s0_ace_cddata;
                    s1_axi_rlast    = 1'b1;
                    s1_axi_bvalid   = s0_ace_cdvalid;
                    s1_axi_bresp    = 2'b00;
                    if (s0_ace_cdvalid) begin
                        next_state = IDLE; // done, no mem write
                    end
                    else begin
                        next_state = DATA_WR_SNOOP;
                    end
                end
            end

            DATA_WR_SNOOP: begin
                // waiting for CD from peer to forward to requester (ownership-transfer)
                if (grant_s0) begin
                    if (s1_ace_cdvalid && s0_axi_rready) begin
                        next_state = IDLE;
                    end
                end
                else begin
                    if (s0_ace_cdvalid && s1_axi_rready) begin
                        next_state = IDLE;
                    end
                end
            end

            DATA_MEM: begin
                // waiting for mem read data; forward to requester until rlast
                if (grant_s0) begin
                    if (mux_m0_rvalid && s0_axi_rready && mux_m0_rlast) begin
                        next_state = IDLE;
                    end
                end
                else begin
                    if (mux_m1_rvalid && s1_axi_rready && mux_m1_rlast) begin
                        next_state = IDLE;
                    end
                end
            end

            DATA_SNOOP: begin
                if (grant_s0) begin
                    if (s1_ace_cdvalid && s0_axi_rready) begin
                        next_state = IDLE;
                    end 
                end 
                else begin
                    if (s0_ace_cdvalid && s1_axi_rready) begin
                        next_state = IDLE;
                    end 
                end
            end
            default: next_state = IDLE;
        endcase
    end
    
    always @(*) begin
        s0_axi_arready  = mux_m0_arready; 
        s0_axi_rvalid   = mux_m0_rvalid; 
        s0_axi_rlast    = mux_m0_rlast; 
        s0_axi_rdata    = mux_m0_rdata;

        // Write defaults - client 0
        s0_axi_awready  = mux_m0_awready;
        s0_axi_wready   = mux_m0_wready;
        s0_axi_bvalid   = mux_m0_bvalid;
        s0_axi_bresp    = mux_m0_bresp;
        s1_axi_arready  = mux_m1_arready; 
        s1_axi_rvalid   = mux_m1_rvalid; 
        s1_axi_rlast    = mux_m1_rlast; 
        s1_axi_rdata    = mux_m1_rdata;

        // Write defaults - client 1
        s1_axi_awready  = mux_m1_awready;
        s1_axi_wready   = mux_m1_wready;
        s1_axi_bvalid   = mux_m1_bvalid;
        s1_axi_bresp    = mux_m1_bresp;
        s0_ace_acvalid  = 1'b0; 
        s0_ace_acaddr   = {ADDR_W{1'b0}}; 
        s0_ace_acsnoop  = 4'b0;

        s1_ace_acvalid  = 1'b0; 
        s1_ace_acaddr   = {ADDR_W{1'b0}}; 
        s1_ace_acsnoop  = 4'b0;

        // (mem_* signals are driven by the master mux)
        case(state)
            SNOOP_REQ: begin
                if (grant_s0) begin 
                    s1_ace_acvalid  = 1'b1;
                    s1_ace_acaddr   = (is_write_request) ? s0_axi_awaddr : s0_axi_araddr;
                    s1_ace_acsnoop  = s0_axi_arsnoop; 
                end 
                else begin 
                    s0_ace_acvalid  = 1'b1;
                    s0_ace_acaddr   = (is_write_request) ? s1_axi_awaddr : s1_axi_araddr;
                    s0_ace_acsnoop  = s1_axi_arsnoop; 
                end
            end

            MEM_REQ: begin 
                // mem request: address/valid forwarded by master mux
                // state transition waits on mem_arready (handled above)
            end

            MEM_WR_REQ: begin
                // mem write request: AW/W/B handled by master mux; state transition waits on mem_awready && mem_wready
            end

            DATA_MEM: begin
                // DATA_MEM: read data forwarded by master mux
            end

            DATA_WR_SNOOP: begin
                // DATA_WR_SNOOP: snoop CD is used as write data source via m*_wdata_int
            end

            DATA_SNOOP: begin
                 if (grant_s0) begin
                    s0_axi_arready  = 1'b1; // Ack request xong
                    s0_axi_rvalid   = s1_ace_cdvalid;
                    s0_axi_rdata    = s1_ace_cddata;
                    s0_axi_rlast    = 1'b1;
                 end 
                 else begin
                    s1_axi_arready  = 1'b1;
                    s1_axi_rvalid   = s0_ace_cdvalid;
                    s1_axi_rdata    = s0_ace_cddata;
                    s1_axi_rlast    = 1'b1;
                 end
            end
        endcase
    end

endmodule