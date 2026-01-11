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
    output reg              m_l3_rready
);
    localparam IDLE         = 3'd0;
    localparam SNOOP_REQ    = 3'd1; // Gui lenh snoop sang core kia
    localparam WAIT_CR      = 3'd2; // doi core kia check tag xong
    localparam DATA_L3      = 3'd3; // Miss snoop -> Lay data tu L3
    localparam DATA_SNOOP   = 3'd4; // Hit snoop -> Lay data tu Core kia

    reg [2:0] state, next_state;
    reg grant_s0;

    reg snoop_hit_data;

    // -------------------------------------------------------- ARBITER & STATE MACHINE --------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state           <= IDLE;
            grant_s0        <= 1'b0;
            snoop_hit_data  <= 1'b0;
        end else begin
            state <= next_state;
            
            case(state)
                IDLE: begin
                    if (s0_axi_arvalid) begin      
                        grant_s0 <= 1'b1;
                    end 
                    else if (s1_axi_arvalid) begin 
                        grant_s0 <= 1'b0;
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
                if (s0_axi_arvalid | s1_axi_arvalid) begin
                    next_state = SNOOP_REQ;
                end
            end

            SNOOP_REQ: begin
                // doi gui thanh cong lenh Snoop (AC) va lenh L3 (AR)
                // (Gia su L3 luon nhan duoc, chi check AC ready)
                if (grant_s0) begin
                    if (s1_ace_acready && m_l3_arready) begin 
                        next_state = WAIT_CR;
                    end 
                end else begin
                    if (s0_ace_acready && m_l3_arready) begin 
                        next_state = WAIT_CR;
                    end 
                end
            end

            WAIT_CR: begin
                // doi phan hoi tu Core kia (Snoop Response)
                if (grant_s0 && s1_ace_crvalid) begin
                    // Neu Core B bao co Data -> Qua DATA_SNOOP, ngc lai DATA_L3
                    if (s1_ace_crresp[3]) begin 
                        next_state = DATA_SNOOP;
                    end 
                    else begin                  
                        next_state = DATA_L3;
                    end 
                end 
                else if (!grant_s0 && s0_ace_crvalid) begin
                    if (s0_ace_crresp[3]) begin 
                        next_state = DATA_SNOOP;
                    end 
                    else begin                  
                        next_state = DATA_L3;
                    end 
                end
            end

            DATA_L3: begin
                // Truyen data tu L3 ve Master
                // Xong khi nhan duoc rlast
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

            DATA_SNOOP: begin
                // Truyen data tu CD Channel (Snoop) ve Master
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
            default: begin
                next_state = IDLE;
            end 
        endcase
    end
    
    always @(*) begin
        // Default values
        s0_axi_arready  = 1'b0; 
        s0_axi_rvalid   = 1'b0; 
        s0_axi_rlast    = 1'b0; 
        s0_axi_rdata    = {DATA_W{1'b0}};

        s1_axi_arready  = 1'b0; 
        s1_axi_rvalid   = 1'b0; 
        s1_axi_rlast    = 1'b0; 
        s1_axi_rdata    = {DATA_W{1'b0}};
        
        s0_ace_acvalid  = 1'b0; 
        s0_ace_acaddr   = {ADDR_W{1'b0}}; 
        s0_ace_acsnoop  = 4'b0;

        s1_ace_acvalid  = 1'b0; 
        s1_ace_acaddr   = {ADDR_W{1'b0}}; 
        s1_ace_acsnoop  = 4'b0;
        
        m_l3_arvalid    = 1'b0; 
        m_l3_araddr     = {ADDR_W{1'b0}}; 
        m_l3_rready     = 1'b0;

        case(state)
            SNOOP_REQ: begin
                // Forward AR Request -> L3
                m_l3_arvalid = 1'b1;
                
                if (grant_s0) begin // S0 Request -> Snoop S1
                    m_l3_araddr     = s0_axi_araddr;
                    s1_ace_acvalid  = 1'b1;
                    s1_ace_acaddr   = s0_axi_araddr;
                    s1_ace_acsnoop  = s0_axi_arsnoop; 
                    
                    // Chi ack ARReady khi ca L3 va S1 da nhan lenh
                    if (m_l3_arready && s1_ace_acready) begin 
                        s0_axi_arready = 1'b1;
                    end
                end 
                else begin // S1 Request -> Snoop S0
                    m_l3_araddr     = s1_axi_araddr;
                    s0_ace_acvalid  = 1'b1;
                    s0_ace_acaddr   = s1_axi_araddr;
                    s0_ace_acsnoop  = s1_axi_arsnoop; 

                    if (m_l3_arready && s0_ace_acready) begin 
                        s1_axi_arready = 1'b1;
                    end 
                end
            end

            DATA_L3: begin
                // Mux: L3 R-Channel -> Master R-Channel
                m_l3_rready = 1'b1; // Luon san sang nhan tu L3
                
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

            DATA_SNOOP: begin
                // Mux: CD Channel (Snoop Data) -> Master R-Channel
                m_l3_rready = 1'b1; // Consume cho het data L3 de ko bi ket

                if (grant_s0) begin
                    // Lay data tu S1 tra cho S0
                    s0_axi_rvalid = s1_ace_cdvalid;
                    s0_axi_rdata  = s1_ace_cddata;
                    s0_axi_rlast  = 1'b1; 
                end else begin
                    // Lay data tu S0 tra cho S1
                    s1_axi_rvalid = s0_ace_cdvalid;
                    s1_axi_rdata  = s0_ace_cddata;
                    s1_axi_rlast  = 1'b1;
                end
            end
        endcase
    end

endmodule