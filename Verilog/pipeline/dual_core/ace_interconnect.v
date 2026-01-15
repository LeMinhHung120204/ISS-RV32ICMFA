`timescale 1ns/1ps
module ace_interconnect #(
    parameter ADDR_W = 32,
    parameter DATA_W = 512, // Cache Line Width (Wide Bus)
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

    // ================= MASTER PORT (TO L3 CACHE) =================
    output [ADDR_W-1:0] m_l3_araddr,
    output              m_l3_arvalid,
    input               m_l3_arready,

    input  [DATA_W-1:0] m_l3_rdata,
    input               m_l3_rvalid,
    input               m_l3_rlast,
    output              m_l3_rready,

    // Write channels to L3 (basic support)
    output [ADDR_W-1:0] m_l3_awaddr,
    output              m_l3_awvalid,
    input               m_l3_awready,

    output [DATA_W-1:0] m_l3_wdata,
    output              m_l3_wvalid,
    input               m_l3_wready,

    input               m_l3_bvalid,
    input  [1:0]        m_l3_bresp,
    output              m_l3_bready
);
    localparam IDLE             = 3'd0;
    localparam SNOOP_REQ        = 3'd1; // Gui lenh snoop sang core kia
    localparam WAIT_CR          = 3'd2; // doi core kia check tag xong
    localparam L3_REQ           = 3'd3;
    localparam DATA_L3          = 3'd4; // Miss snoop -> Lay data tu L3
    localparam DATA_SNOOP       = 3'd5; // Hit snoop -> Lay data tu Core kia
    localparam L3_WR_REQ        = 3'd6; // Write request to L3
    localparam DATA_WR_SNOOP    = 3'd7; // Write - obtain data from snoop

    reg [2:0] state, next_state;
    reg grant_s0;

    reg is_write_request;

    // --------------------------------------------------------
    // Internal wires for arbiter + mux
    wire r_grant0, r_grant1;
    wire w_grant0, w_grant1;

    // Master-mux wires (slave side = memory)
    wire [ADDR_W-1:0] mux_s_araddr;
    wire              mux_s_arvalid;
    wire              mux_s_arready;
    wire [DATA_W-1:0] mux_s_rdata;
    wire              mux_s_rvalid;
    wire              mux_s_rlast;
    wire              mux_s_rready;

    wire [ADDR_W-1:0] mux_s_awaddr;
    wire              mux_s_awvalid;
    wire              mux_s_awready;
    wire [DATA_W-1:0] mux_s_wdata;
    wire              mux_s_wvalid;
    wire              mux_s_wready;
    wire              mux_s_bvalid;
    wire [1:0]        mux_s_bresp;
    wire              mux_s_bready;

    // Master-side wires from mux to clients
    wire mux_m0_arready, mux_m1_arready;
    wire [DATA_W-1:0] mux_m0_rdata, mux_m1_rdata;
    wire mux_m0_rvalid, mux_m1_rvalid;
    wire mux_m0_rlast, mux_m1_rlast;
    wire mux_m0_awready, mux_m1_awready;
    wire mux_m0_wready, mux_m1_wready;
    wire mux_m0_bvalid, mux_m1_bvalid;
    wire [1:0] mux_m0_bresp, mux_m1_bresp;

    // Internal write-data sources (allow snoop -> write path)
    reg [DATA_W-1:0]    m0_wdata_int, m1_wdata_int;
    reg                 m0_wvalid_int, m1_wvalid_int;

    // -------------------------------------------------------- ARBITER & STATE MACHINE --------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state           <= IDLE;
            grant_s0        <= 1'b0;
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
        .m0_ARVALID (s0_axi_arvalid & grant_s0),
        .m0_RREADY  (s0_axi_rready),
        .m1_ARVALID (s1_axi_arvalid & ~grant_s0),
        .m1_RREADY  (s1_axi_rready),
        .s_RVALID   (m_l3_rvalid),
        .s_RLAST    (m_l3_rlast),
        .m0_rgrnt   (r_grant0),
        .m1_rgrnt   (r_grant1)
    );

    // Instantiate write arbiter (mask AW/W by grant_s0)
    AXI_Arbiter_W u_arb_w (
        .ACLK       (clk),
        .ARESETn    (rst_n),
        .m0_AWVALID (s0_axi_awvalid & grant_s0),
        .m0_WVALID  (s0_axi_wvalid & grant_s0),
        .m0_BREADY  (s0_axi_bready),
        .m1_AWVALID (s1_axi_awvalid & ~grant_s0),
        .m1_WVALID  (s1_axi_wvalid & ~grant_s0),
        .m1_BREADY  (s1_axi_bready),
        .s_BVALID   (m_l3_bvalid),
        .m0_wgrnt   (w_grant0),
        .m1_wgrnt   (w_grant1)
    );

    // Prepare write-data sources: by default take client W, but in DATA_WR_SNOOP override to snoop CD
    always @(*) begin
        m0_wdata_int = s0_axi_wdata;
        m1_wdata_int = s1_axi_wdata;
        m0_wvalid_int = s0_axi_wvalid & grant_s0;
        m1_wvalid_int = s1_axi_wvalid & ~grant_s0;
        if (state == DATA_WR_SNOOP) begin
            if (grant_s0) begin
                // granted master is 0, data comes from snoop source core1
                m0_wdata_int = s1_ace_cddata;
                m0_wvalid_int = s1_ace_cdvalid;
                m1_wdata_int = s1_axi_wdata; // keep others unchanged
            end else begin
                // granted master is 1, data comes from snoop source core0
                m1_wdata_int = s0_ace_cddata;
                m1_wvalid_int = s0_ace_cdvalid;
                m0_wdata_int = s0_axi_wdata;
            end
        end
    end

    // Instantiate master muxes
    AXI_Master_Mux_R #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_mux_r (
        .clk        (clk), 
        .m0_araddr  (s0_axi_araddr),
        .m0_arvalid (s0_axi_arvalid & grant_s0),
        .m0_arready (mux_m0_arready),
        .m0_rdata   (mux_m0_rdata),
        .m0_rvalid  (mux_m0_rvalid),
        .m0_rlast   (mux_m0_rlast),
        .m0_rready  (s0_axi_rready),
        .m1_araddr  (s1_axi_araddr),
        .m1_arvalid (s1_axi_arvalid & ~grant_s0),
        .m1_arready (mux_m1_arready),
        .m1_rdata   (mux_m1_rdata),
        .m1_rvalid  (mux_m1_rvalid),
        .m1_rlast   (mux_m1_rlast),
        .m1_rready  (s1_axi_rready),
        .s_araddr   (mux_s_araddr),
        .s_arvalid  (mux_s_arvalid),
        .s_arready  (m_l3_arready),
        .s_rdata    (m_l3_rdata),
        .s_rvalid   (m_l3_rvalid),
        .s_rlast    (m_l3_rlast),
        .s_rready   (mux_s_rready),
        .m0_rgrnt   (r_grant0),
        .m1_rgrnt   (r_grant1)
    );

    AXI_Master_Mux_W #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_mux_w (
        .clk        (clk),
        .m0_awaddr  (s0_axi_awaddr),
        .m0_awvalid (s0_axi_awvalid & grant_s0),
        .m0_awready (mux_m0_awready),
        .m0_wdata   (m0_wdata_int),
        .m0_wvalid  (m0_wvalid_int),
        .m0_wready  (mux_m0_wready),
        .m0_bvalid  (mux_m0_bvalid),
        .m0_bresp   (mux_m0_bresp),
        .m0_bready  (s0_axi_bready),
        .m1_awaddr  (s1_axi_awaddr),
        .m1_awvalid (s1_axi_awvalid & ~grant_s0),
        .m1_awready (mux_m1_awready),
        .m1_wdata   (m1_wdata_int),
        .m1_wvalid  (m1_wvalid_int),
        .m1_wready  (mux_m1_wready),
        .m1_bvalid  (mux_m1_bvalid),
        .m1_bresp   (mux_m1_bresp),
        .m1_bready  (s1_axi_bready),
        .s_awaddr   (mux_s_awaddr),
        .s_awvalid  (mux_s_awvalid),
        .s_awready  (m_l3_awready),
        .s_wdata    (mux_s_wdata),
        .s_wvalid   (mux_s_wvalid),
        .s_wready   (m_l3_wready),
        .s_bvalid   (m_l3_bvalid),
        .s_bresp    (m_l3_bresp),
        .s_bready   (mux_s_bready),
        .m0_wgrnt   (w_grant0),
        .m1_wgrnt   (w_grant1)
    );

    // Connect mux slave-side nets to top-level m_l3_* outputs/inputs
    assign m_l3_araddr  = mux_s_araddr;
    assign m_l3_arvalid = mux_s_arvalid;
    assign m_l3_rready  = mux_s_rready;
    assign m_l3_awaddr  = mux_s_awaddr;
    assign m_l3_awvalid = mux_s_awvalid;
    assign m_l3_wdata   = mux_s_wdata;
    assign m_l3_wvalid  = mux_s_wvalid;
    assign m_l3_bready  = mux_s_bready;

    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if (s0_axi_arvalid || s1_axi_arvalid || s0_axi_awvalid || s1_axi_awvalid) begin
                    next_state = SNOOP_REQ;
                end 
            end

            SNOOP_REQ: begin
                // Buoc 1: Chi gui Snoop sang Core kia (KHONG GUI L3 O DAY)
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

            WAIT_CR: begin
                // Buoc 2: Doi phan hoi
                if (grant_s0 && s1_ace_crvalid) begin
                    // Neu HIT DIRTY (bit 3) -> Lay data từ Core B
                    if (s1_ace_crresp[3]) begin
                        // If original request was write, go to write-snoop data state
                        if (is_write_request) begin 
                            next_state = DATA_WR_SNOOP;
                        end 
                        else begin 
                            next_state = DATA_SNOOP;
                        end 
                    end 
                    // Neu MISS/CLEAN -> doc tu L3
                    else begin    
                        if (is_write_request) begin
                            next_state = L3_WR_REQ; 
                        end 
                        else begin
                            next_state = L3_REQ; 
                        end
                    end 
                end 
                else if (!grant_s0 && s0_ace_crvalid) begin
                    if (s0_ace_crresp[3]) begin
                        if (is_write_request) begin
                            next_state = DATA_WR_SNOOP;
                        end 
                        else begin
                            next_state = DATA_SNOOP;
                        end
                    end 
                    else begin                  
                        if (is_write_request) begin
                            next_state = L3_WR_REQ;
                        end 
                        else begin
                            next_state = L3_REQ;
                        end
                    end 
                end
            end

            L3_REQ: begin
                // Buoc 3: Gui request xuong L3
                if (m_l3_arready) begin
                    next_state = DATA_L3;
                end
            end

            L3_WR_REQ: begin
                // Send write request to L3: wait for AW handshake and W handshake
                if (m_l3_awready && m_l3_wready) begin
                    next_state = IDLE;
                end
            end

            DATA_L3: begin
                if (grant_s0) begin
                    if (m_l3_rvalid && m_l3_rlast && s0_axi_rready)begin 
                        next_state = IDLE;
                    end 
                end 
                else begin
                    if (m_l3_rvalid && m_l3_rlast && s1_axi_rready) begin
                        next_state = IDLE;
                    end 
                end
            end

            DATA_WR_SNOOP: begin
                // For write snoop: wait for CD from snooping core then forward to L3
                if (grant_s0) begin
                    if (s1_ace_cdvalid && m_l3_wready) begin
                        next_state = L3_WR_REQ;
                    end
                end else begin
                    if (s0_ace_cdvalid && m_l3_wready) begin
                        next_state = L3_WR_REQ;
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

        // (m_l3_* signals are driven by the master mux)
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

            L3_REQ: begin 
                // L3 request: address/valid forwarded by master mux
                // state transition waits on m_l3_arready (handled above)
            end

            L3_WR_REQ: begin
                // L3 write request: AW/W/B handled by master mux; state transition waits on m_l3_awready && m_l3_wready
            end

            DATA_L3: begin
                // DATA_L3: read data forwarded by master mux
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