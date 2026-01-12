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
    output reg [ADDR_W-1:0] m_l3_araddr,
    output reg              m_l3_arvalid,
    input                   m_l3_arready,

    input  [DATA_W-1:0]     m_l3_rdata,
    input                   m_l3_rvalid,
    input                   m_l3_rlast,
    output reg              m_l3_rready,

    // Write channels to L3 (basic support)
    output reg [ADDR_W-1:0] m_l3_awaddr,
    output reg              m_l3_awvalid,
    input                   m_l3_awready,

    output reg [DATA_W-1:0] m_l3_wdata,
    output reg              m_l3_wvalid,
    input                   m_l3_wready,

    input                   m_l3_bvalid,
    input  [1:0]            m_l3_bresp,
    output reg              m_l3_bready
);
    localparam IDLE         = 3'd0;
    localparam SNOOP_REQ    = 3'd1; // Gui lenh snoop sang core kia
    localparam WAIT_CR      = 3'd2; // doi core kia check tag xong
    localparam L3_REQ       = 3'd3;
    localparam DATA_L3      = 3'd4; // Miss snoop -> Lay data tu L3
    localparam DATA_SNOOP   = 3'd5; // Hit snoop -> Lay data tu Core kia
    localparam L3_WR_REQ    = 3'd6; // Write request to L3
    localparam DATA_WR_SNOOP= 3'd7; // Write - obtain data from snoop

    reg [2:0] state, next_state;
    reg grant_s0;

    reg snoop_hit_data;
    reg is_write_request;
    reg [DATA_W-1:0] saved_wdata;

    // -------------------------------------------------------- ARBITER & STATE MACHINE --------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state           <= IDLE;
            grant_s0        <= 1'b0;
            snoop_hit_data  <= 1'b0;
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
                        // capture write data if available
                        if (s0_axi_awvalid && s0_axi_wvalid) begin 
                            saved_wdata <= s0_axi_wdata;
                        end 
                        else if (s1_axi_awvalid && s1_axi_wvalid) begin
                            saved_wdata <= s1_axi_wdata;
                        end
                    end 
                    else begin
                        is_write_request <= 1'b0;
                    end
                end
                 
                WAIT_CR: begin
                    if (grant_s0 && s1_ace_crvalid) begin
                        snoop_hit_data <= s1_ace_crresp[3]; // Bit 3 của CRRESP la DataTransfer
                    end 
                    else if (!grant_s0 && s0_ace_crvalid) begin
                        snoop_hit_data <= s0_ace_crresp[3];
                    end 
                end 
            endcase
        end
    end

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
        s0_axi_arready  = 1'b0; 
        s0_axi_rvalid   = 1'b0; 
        s0_axi_rlast    = 1'b0; 
        s0_axi_rdata    = {DATA_W{1'b0}};

        // Write defaults - client 0
        s0_axi_awready  = 1'b0;
        s0_axi_wready   = 1'b0;
        s0_axi_bvalid   = 1'b0;
        s0_axi_bresp    = 2'b00;
        s1_axi_arready  = 1'b0; 
        s1_axi_rvalid   = 1'b0; 
        s1_axi_rlast    = 1'b0; 
        s1_axi_rdata    = {DATA_W{1'b0}};

        // Write defaults - client 1
        s1_axi_awready  = 1'b0;
        s1_axi_wready   = 1'b0;
        s1_axi_bvalid   = 1'b0;
        s1_axi_bresp    = 2'b00;
        s0_ace_acvalid  = 1'b0; 
        s0_ace_acaddr   = {ADDR_W{1'b0}}; 
        s0_ace_acsnoop  = 4'b0;

        s1_ace_acvalid  = 1'b0; 
        s1_ace_acaddr   = {ADDR_W{1'b0}}; 
        s1_ace_acsnoop  = 4'b0;

        m_l3_arvalid    = 1'b0; 
        m_l3_araddr     = {ADDR_W{1'b0}}; 
        m_l3_rready     = 1'b0;

        // L3 write defaults
        m_l3_awvalid    = 1'b0;
        m_l3_awaddr     = {ADDR_W{1'b0}};
        m_l3_wvalid     = 1'b0;
        m_l3_wdata      = {DATA_W{1'b0}};
        m_l3_bready     = 1'b0;
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
                m_l3_arvalid = 1'b1;
                if (grant_s0) begin 
                    m_l3_araddr = s0_axi_araddr;
                end 
                else begin          
                    m_l3_araddr = s1_axi_araddr;
                end 

                // Khi L3 nhan lenh, coi như xong pha Request -> Ready cho Core A/B
                if (m_l3_arready) begin
                    if (grant_s0) begin 
                        s0_axi_arready = 1'b1;
                    end 
                    else begin          
                        s1_axi_arready = 1'b1;
                    end 
                end
            end

            L3_WR_REQ: begin
                // Forward AW to L3
                m_l3_awvalid = 1'b1;
                m_l3_awaddr  = (grant_s0) ? s0_axi_awaddr : s1_axi_awaddr;

                // Choose write data: prefer snoop CD if hit, else client W
                if (snoop_hit_data) begin
                    m_l3_wvalid = 1'b1;
                    m_l3_wdata  = (grant_s0) ? s1_ace_cddata : s0_ace_cddata;
                end 
                else begin
                    if (grant_s0) begin
                        m_l3_wvalid = s0_axi_wvalid;
                        m_l3_wdata  = s0_axi_wdata;
                    end 
                    else begin
                        m_l3_wvalid = s1_axi_wvalid;
                        m_l3_wdata  = s1_axi_wdata;
                    end
                end

                // If L3 accepts address/data, acknowledge cores
                if (m_l3_awready) begin
                    if (grant_s0) begin
                        s0_axi_awready = 1'b1; 
                    end 
                    else begin
                        s1_axi_awready = 1'b1;
                    end
                end
                if (m_l3_wready) begin
                    if (grant_s0) begin
                        s0_axi_wready = 1'b1; 
                    end 
                    else begin
                        s1_axi_wready = 1'b1;
                    end
                end

                // Forward write response B from L3 to granted core
                if (m_l3_bvalid) begin
                    if (grant_s0) begin
                        s0_axi_bvalid = 1'b1;
                        s0_axi_bresp  = m_l3_bresp;
                        m_l3_bready   = s0_axi_bready;
                    end 
                    else begin
                        s1_axi_bvalid = 1'b1;
                        s1_axi_bresp  = m_l3_bresp;
                        m_l3_bready   = s1_axi_bready;
                    end
                end
            end

            DATA_L3: begin
                m_l3_rready = 1'b1;
                if (grant_s0) begin
                    s0_axi_rvalid   = m_l3_rvalid;
                    s0_axi_rdata    = m_l3_rdata;
                    s0_axi_rlast    = m_l3_rlast;
                end 
                else begin
                    s1_axi_rvalid   = m_l3_rvalid;
                    s1_axi_rdata    = m_l3_rdata;
                    s1_axi_rlast    = m_l3_rlast;
                end
            end

                DATA_WR_SNOOP: begin
                    // Receive data from snooping core and forward as W to L3
                    if (grant_s0) begin
                        // snoop source is core1
                        m_l3_wvalid = s1_ace_cdvalid;
                        m_l3_wdata  = s1_ace_cddata;
                        if (m_l3_wready) begin
                            s0_axi_wready = 1'b1;
                        end
                    end 
                    else begin
                        m_l3_wvalid = s0_ace_cdvalid;
                        m_l3_wdata  = s0_ace_cddata;
                        if (m_l3_wready) begin 
                            s1_axi_wready = 1'b1;  
                        end 
                    end
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