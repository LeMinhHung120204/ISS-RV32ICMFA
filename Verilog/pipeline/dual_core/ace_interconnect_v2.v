`timescale 1ns/1ps
// from Lee Min Hunz with luv
// ============================================================================
// ACE Interconnect v2 - Dual-Core Cache Coherence Controller
// ============================================================================
// 
// This module implements an ACE (AXI Coherent Extension) interconnect for
// a dual-core system. It manages cache coherence between two cores using
// the snoop protocol.
//
// Key Features:
//   - Round-robin arbitration for read/write requests
//   - Snoop protocol for cache-to-cache transfers
//   - Supports ReadShared, ReadUnique, CleanInvalid, MakeInvalid
//   - Separate FSMs for read and write transactions
//
// Transaction Flow (Read Example):
//   1. Core A issues read request (AR channel)
//   2. Interconnect snoops Core B (AC channel) 
//   3. Core B responds with state (CR channel)
//   4. If hit: Core B sends data (CD channel) -> Core A
//      If miss: Interconnect fetches from memory -> Core A
//
// ============================================================================
module ace_interconnect_v2 #(
    parameter ADDR_W    = 32,
    parameter DATA_W    = 32,
    parameter STRB_W    = DATA_W / 8,
    parameter ID_W      = 2
)(
    input clk, rst_n

    // ================= CLIENT 0 (CORE A) =================
    // AR Channel
,   input   [ID_W-1:0]      s0_axi_arid
,   input   [ADDR_W-1:0]    s0_axi_araddr
,   input   [7:0]           s0_axi_arlen
,   input   [2:0]           s0_axi_arsize
,   input   [1:0]           s0_axi_arburst
,   input   [3:0]           s0_axi_arsnoop
,   input                   s0_axi_arvalid
,   output                  s0_axi_arready
    // AW/W/B Channel (Write)
,   input   [ID_W-1:0]      s0_axi_awid
,   input   [ADDR_W-1:0]    s0_axi_awaddr
,   input   [7:0]           s0_axi_awlen
,   input   [2:0]           s0_axi_awsize
,   input   [1:0]           s0_axi_awburst
,   input   [2:0]           s0_axi_awsnoop
,   input                   s0_axi_awvalid
,   output                  s0_axi_awready

,   input   [DATA_W-1:0]    s0_axi_wdata
,   input   [STRB_W-1:0]    s0_axi_wstrb
,   input                   s0_axi_wlast
,   input                   s0_axi_wvalid
,   output                  s0_axi_wready
,   output                  s0_axi_bvalid
,   output  [ID_W-1:0]      s0_axi_bid
,   output  [1:0]           s0_axi_bresp
,   input                   s0_axi_bready
    
    // R Channel
,   output  [DATA_W-1:0]    s0_axi_rdata
,   output  [ID_W-1:0]      s0_axi_rid
,   output  [3:0]           s0_axi_rresp
,   output                  s0_axi_rvalid
,   output                  s0_axi_rlast
,   input                   s0_axi_rready

    // AC Channel (Snoop Input to Core A)
,   output reg [ADDR_W-1:0] s0_ace_acaddr
,   output reg [3:0]        s0_ace_acsnoop
,   output reg              s0_ace_acvalid
,   input                   s0_ace_acready

    // CR/CD Channel (Snoop Response from Core A)
,   input                   s0_ace_crvalid
,   input   [4:0]           s0_ace_crresp
,   input   [DATA_W-1:0]    s0_ace_cddata
,   input                   s0_ace_cdvalid
,   input                   s0_ace_cdlast

    // ================= CLIENT 1 (CORE B) =================
    // AR Channel
,   input   [ID_W-1:0]      s1_axi_arid
,   input   [ADDR_W-1:0]    s1_axi_araddr
,   input   [7:0]           s1_axi_arlen
,   input   [2:0]           s1_axi_arsize
,   input   [1:0]           s1_axi_arburst
,   input   [3:0]           s1_axi_arsnoop
,   input                   s1_axi_arvalid
,   output                  s1_axi_arready

    // AW/W/B Channel (Write)
,   input   [ID_W-1:0]      s1_axi_awid
,   input   [ADDR_W-1:0]    s1_axi_awaddr
,   input   [7:0]           s1_axi_awlen
,   input   [2:0]           s1_axi_awsize
,   input   [1:0]           s1_axi_awburst
,   input   [2:0]           s1_axi_awsnoop
,   input                   s1_axi_awvalid
,   output                  s1_axi_awready

,   input   [DATA_W-1:0]    s1_axi_wdata
,   input   [STRB_W-1:0]    s1_axi_wstrb
,   input                   s1_axi_wlast
,   input                   s1_axi_wvalid
,   output                  s1_axi_wready
    
,   output                  s1_axi_bvalid
,   output  [ID_W-1:0]      s1_axi_bid
,   output  [1:0]           s1_axi_bresp
,   input                   s1_axi_bready
    
,   output  [DATA_W-1:0]    s1_axi_rdata
,   output  [ID_W-1:0]      s1_axi_rid
,   output  [3:0]           s1_axi_rresp
,   output                  s1_axi_rvalid
,   output                  s1_axi_rlast
,   input                   s1_axi_rready

    // AC Channel (Snoop Input to Core B)
,   output reg [ADDR_W-1:0] s1_ace_acaddr
,   output reg [3:0]        s1_ace_acsnoop
,   output reg              s1_ace_acvalid
,   input                   s1_ace_acready

    // CR/CD Channel (Snoop Response from Core B)
,   input                   s1_ace_crvalid
,   input   [4:0]           s1_ace_crresp
,   input   [DATA_W-1:0]    s1_ace_cddata
,   input                   s1_ace_cdvalid
,   input                   s1_ace_cdlast

    // ================================================================ MASTER PORT (TO EXTERNAL MEMORY) ================================================================
    // READ
,   output  [ID_W-1:0]      mem_arid
,   output  [ADDR_W-1:0]    mem_araddr
,   output  [7:0]           mem_arlen
,   output  [2:0]           mem_arsize
,   output  [1:0]           mem_arburst
,   output                  mem_arvalid
,   input                   mem_arready

,   input   [DATA_W-1:0]    mem_rdata
,   input   [ID_W-1:0]      mem_rid
,   input   [3:0]           mem_rresp
,   input                   mem_rvalid
,   input                   mem_rlast
,   output                  mem_rready

    // WRITE
,   output  [ID_W-1:0]      mem_awid
,   output  [ADDR_W-1:0]    mem_awaddr
,   output  [7:0]           mem_awlen
,   output  [2:0]           mem_awsize
,   output  [1:0]           mem_awburst
,   output                  mem_awvalid
,   input                   mem_awready
    
,   output  [DATA_W-1:0]    mem_wdata
,   output  [STRB_W-1:0]    mem_wstrb
,   output                  mem_wlast
,   output                  mem_wvalid
,   input                   mem_wready
    
,   input                   mem_bvalid
,   input   [ID_W-1:0]      mem_bid
,   input   [1:0]           mem_bresp
,   output                  mem_bready
);

    // ================================================================
    // LOCAL PARAMETERS - FSM States
    // ================================================================
    // Read FSM: IDLE -> SNOOP_REQ -> WAIT_CR -> (R_MEM_REQ/R_DATA_SNOOP) -> IDLE
    // Write FSM: IDLE -> SNOOP_REQ -> WAIT_CR -> (W_MEM_REQ/W_DATA_SNOOP) -> IDLE
    // ================================================================
    
    // Common States (shared encoding)
    localparam IDLE         = 3'd0;     // Waiting for request
    localparam SNOOP_REQ    = 3'd1;     // Sending snoop to peer core (AC channel)
    localparam WAIT_CR      = 3'd2;     // Waiting for snoop response (CR channel)
    
    // Read FSM States
    localparam R_MEM_REQ    = 3'd3;     // Send read request to memory
    localparam R_DATA_MEM   = 3'd4;     // Receive data from memory
    localparam R_DATA_SNOOP = 3'd5;     // Receive data from peer cache (CD channel)
    
    // Write FSM States  
    localparam W_MEM_REQ    = 3'd3;     // Send write request to memory
    localparam W_DATA_SNOOP = 3'd4;     // Peer has dirty data (ownership transfer)
    localparam W_WAIT_B     = 3'd5;     // Wait for write response (B channel)

    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    // FSM State Registers
    reg [2:0]           r_state, r_next_state;      // Read FSM
    reg [2:0]           w_state, w_next_state;      // Write FSM

    // Pending Flags (track active requests)
    reg                 s0_pending_r, s1_pending_r; // Read pending
    reg                 s0_pending_w, s1_pending_w; // Write pending

    // Read Request Buffers (captured from AR channel)
    reg [ID_W-1:0]      s0_ar_id,    s1_ar_id;
    reg [ADDR_W-1:0]    s0_ar_addr,  s1_ar_addr;
    reg [3:0]           s0_ar_snoop, s1_ar_snoop;
    
    // Write Request Buffers (captured from AW channel)
    reg [ID_W-1:0]      s0_aw_id,    s1_aw_id;
    reg [ADDR_W-1:0]    s0_aw_addr,  s1_aw_addr;
    reg [2:0]           s0_aw_snoop, s1_aw_snoop;

    // Grant & Arbitration Registers (Round-Robin)
    reg                 grant_r_s0, last_grant_r;   // Read arbitration
    reg                 grant_w_s0, last_grant_w;   // Write arbitration

    // Snoop Response Capture
    reg [4:0]           r_snoop_resp_capt;          // Captured snoop response

    // ================================================================
    // WIRE DECLARATIONS
    // ================================================================
    // Read Data Mux Output (selects between memory and snoop data)
    wire [DATA_W-1:0]   mux_s0_rdata,  mux_s1_rdata;
    wire [ID_W-1:0]     mux_s0_rid,    mux_s1_rid;
    wire [3:0]          mux_s0_rresp,  mux_s1_rresp;
    wire                mux_s0_rvalid, mux_s1_rvalid;
    wire                mux_s0_rlast,  mux_s1_rlast;

    // Gated Ready Signals (only accept data when in correct state)
    wire                m0_rready_gated;
    wire                m1_rready_gated;

    // ================================================================
    // READ DATA PATH MUX
    // ================================================================
    // Select data source: Memory (default) or Snoop (cache-to-cache)
    // When in R_DATA_SNOOP state, data comes from peer cache's CD channel

    assign s0_axi_rdata     = (r_state == R_DATA_SNOOP) ? s1_ace_cddata : mux_s0_rdata;
    assign s1_axi_rdata     = (r_state == R_DATA_SNOOP) ? s0_ace_cddata : mux_s1_rdata;

    assign s0_axi_rvalid    = (r_state == R_DATA_SNOOP) ? s1_ace_cdvalid : mux_s0_rvalid;
    assign s1_axi_rvalid    = (r_state == R_DATA_SNOOP) ? s0_ace_cdvalid : mux_s1_rvalid;

    assign s0_axi_rlast     = (r_state == R_DATA_SNOOP) ? s1_ace_cdlast : mux_s0_rlast;
    assign s1_axi_rlast     = (r_state == R_DATA_SNOOP) ? s0_ace_cdlast : mux_s1_rlast;

    assign s0_axi_rresp     = (r_state == R_DATA_SNOOP) ? 4'b0000 : mux_s0_rresp; 
    assign s1_axi_rresp     = (r_state == R_DATA_SNOOP) ? 4'b0000 : mux_s1_rresp;

    assign s0_axi_rid       = (r_state == R_DATA_SNOOP) ? s0_ar_id : mux_s0_rid;
    assign s1_axi_rid       = (r_state == R_DATA_SNOOP) ? s1_ar_id : mux_s1_rid;

    // ================================================================
    // REQUEST CAPTURE & PENDING LOGIC
    // ================================================================
    // Capture AR/AW channel info when handshake occurs (valid & ready)
    // Set pending flag until transaction completes
    // ================================================================
    
    // -------------------- READ REQUEST CAPTURE --------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_pending_r    <= 1'b0;
            s1_pending_r    <= 1'b0;

            s0_ar_id        <= {ID_W{1'b0}};
            s1_ar_id        <= {ID_W{1'b0}};

            s0_ar_addr      <= {ADDR_W{1'b0}};
            s1_ar_addr      <= {ADDR_W{1'b0}};

            s0_ar_snoop     <= 4'd0;
            s1_ar_snoop     <= 4'd0;
        end 
        else begin
            // Core 0 Read Capture
            if (s0_axi_arvalid && s0_axi_arready) begin
                s0_pending_r    <= 1'b1;
                s0_ar_id        <= s0_axi_arid;
                s0_ar_addr      <= s0_axi_araddr;
                s0_ar_snoop     <= s0_axi_arsnoop;
            end 
            else if (r_state != IDLE && r_next_state == IDLE && grant_r_s0) begin
                s0_pending_r    <= 1'b0;
            end

            // Core 1 Read Capture
            if (s1_axi_arvalid && s1_axi_arready) begin
                s1_pending_r    <= 1'b1;
                s1_ar_id        <= s1_axi_arid;
                s1_ar_addr      <= s1_axi_araddr;
                s1_ar_snoop     <= s1_axi_arsnoop;
            end 
            else if (r_state != IDLE && r_next_state == IDLE && !grant_r_s0) begin
                s1_pending_r    <= 1'b0;
            end
        end
    end

    // -------------------- WRITE REQUEST CAPTURE --------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_pending_w    <= 1'b0;
            s1_pending_w    <= 1'b0;

            s0_aw_id        <= {ID_W{1'b0}};
            s1_aw_id        <= {ID_W{1'b0}};

            s0_aw_addr      <= {ADDR_W{1'b0}};
            s1_aw_addr      <= {ADDR_W{1'b0}};

            s0_aw_snoop     <= 3'd0;
            s1_aw_snoop     <= 3'd0;
        end 
        else begin
            // Core 0 Write Capture
            if (s0_axi_awvalid && s0_axi_awready) begin
                s0_pending_w    <= 1'b1;
                s0_aw_id        <= s0_axi_awid;
                s0_aw_addr      <= s0_axi_awaddr;
                s0_aw_snoop     <= s0_axi_awsnoop;
            end 
            else if (w_state != IDLE && w_next_state == IDLE && grant_w_s0) begin
                s0_pending_w    <= 1'b0;
            end

            // Core 1 Write Capture
            if (s1_axi_awvalid && s1_axi_awready) begin
                s1_pending_w    <= 1'b1;
                s1_aw_id        <= s1_axi_awid;
                s1_aw_addr      <= s1_axi_awaddr;
                s1_aw_snoop     <= s1_axi_awsnoop;
            end 
            else if (w_state != IDLE && w_next_state == IDLE && !grant_w_s0) begin
                s1_pending_w    <= 1'b0;
            end
        end
    end

    // Ready Signals: Only accept new request when buffer is empty
    assign s0_axi_arready = !s0_pending_r;
    assign s1_axi_arready = !s1_pending_r;
    assign s0_axi_awready = !s0_pending_w;
    assign s1_axi_awready = !s1_pending_w;

    // ================================================================
    // READ FSM - State Register & Arbitration
    // ================================================================
    // Round-robin arbitration: alternate between cores when both pending
    // ================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state         <= IDLE;
            grant_r_s0      <= 1'b1;
            last_grant_r    <= 1'b1;
        end 
        else begin
            r_state <= r_next_state;
            
            // Arbitration Logic (Round Robin)
            if (r_state == IDLE) begin
                if (s0_pending_r && s1_pending_r) begin
                    grant_r_s0 <= last_grant_r;
                end 
                else if (s0_pending_r) begin
                    grant_r_s0 <= 1'b1;
                end
                else if (s1_pending_r) begin
                    grant_r_s0 <= 1'b0;
                end
            end 
            else if (r_next_state == IDLE) begin
                last_grant_r <= ~grant_r_s0;
            end
        end
    end

    always @(*) begin
        r_next_state = r_state;
        case (r_state)
            IDLE: begin
                if (s0_pending_r || s1_pending_r) begin 
                    r_next_state = SNOOP_REQ;
                end 
            end

            SNOOP_REQ: begin
                // Check if AC Ready (Basic check, assumes priority or availability)
                if (grant_r_s0) begin
                    if (s1_ace_acready) begin
                        r_next_state = WAIT_CR;
                    end 
                end 
                else begin
                    if (s0_ace_acready) begin
                        r_next_state = WAIT_CR;
                    end 
                end
            end

            WAIT_CR: begin
                // Wait for snoop response from peer cache
                // CRRESP[0] = DataTransfer: peer will send data
                // CRRESP[2] = PassDirty: peer has dirty copy
                
                // Core 0 requested, waiting for Core 1's response
                if (grant_r_s0 && s1_ace_crvalid) begin
                    if (s1_ace_crresp[0] || s1_ace_crresp[2]) begin
                        r_next_state = R_DATA_SNOOP; // HIT: Get data from peer
                    end 
                    else begin                                      
                        r_next_state = R_MEM_REQ;    // MISS: Fetch from memory
                    end 
                end 

                // Core 1 requested, waiting for Core 0's response
                else if (!grant_r_s0 && s0_ace_crvalid) begin
                    if (s0_ace_crresp[0] || s0_ace_crresp[2]) begin 
                        r_next_state = R_DATA_SNOOP; // HIT: Get data from peer
                    end 
                    else begin             
                        r_next_state = R_MEM_REQ;    // MISS: Fetch from memory
                    end 
                end
            end

            R_MEM_REQ: begin
                if (mem_arready) begin 
                    r_next_state = R_DATA_MEM;
                end 
            end

            R_DATA_MEM: begin
                // Wait for Mem RLAST
                if (mem_rvalid && mem_rlast && mem_rready) begin 
                    r_next_state = IDLE;
                end 
            end

            R_DATA_SNOOP: begin
                // Receive data burst from peer cache (CD channel)
                // Complete when CDLAST is asserted
                if (grant_r_s0) begin
                    if (s1_ace_cdvalid && s0_axi_rready && s1_ace_cdlast) begin 
                        r_next_state = IDLE;
                    end 
                end 
                else begin
                    if (s0_ace_cdvalid && s1_axi_rready && s0_ace_cdlast) begin 
                        r_next_state = IDLE;
                    end 
                end
            end
            default: r_next_state = IDLE;
        endcase
    end

    // -------------------- Capture Snoop Response (for future use) --------------------
    always @(posedge clk) begin
        if (~rst_n) begin
            r_snoop_resp_capt <= 5'd0;
        end 
        else begin
            if (r_state == WAIT_CR) begin
                if (grant_r_s0 && s1_ace_crvalid) begin       
                    r_snoop_resp_capt <= s1_ace_crresp;
                end 
                else if (!grant_r_s0 && s0_ace_crvalid) begin 
                    r_snoop_resp_capt <= s0_ace_crresp;
                end 
            end
        end
    end

    // ================================================================
    // WRITE FSM - State Register & Arbitration  
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state         <= IDLE;
            grant_w_s0      <= 1'b1;
            last_grant_w    <= 1'b1;
        end else begin
            w_state <= w_next_state;
            
            if (w_state == IDLE) begin
                if (s0_pending_w && s1_pending_w) begin 
                    grant_w_s0  <= last_grant_w;
                end 
                else if (s0_pending_w) begin            
                    grant_w_s0  <= 1'b1;
                end 
                else if (s1_pending_w) begin            
                    grant_w_s0  <= 1'b0;
                end 
            end 
            else if (w_next_state == IDLE) begin
                last_grant_w    <= ~grant_w_s0;
            end
        end
    end

    always @(*) begin
        w_next_state = w_state;
        case (w_state)
            IDLE: begin
                if (s0_pending_w || s1_pending_w) begin 
                    w_next_state = SNOOP_REQ;
                end 
            end

            SNOOP_REQ: begin
                if (grant_w_s0) begin
                    if (s1_ace_acready) begin 
                        w_next_state = WAIT_CR;
                    end
                end 
                else begin
                    if (s0_ace_acready) begin  
                        w_next_state = WAIT_CR;
                    end 
                end
            end

            WAIT_CR: begin   
                // Wait for snoop response
                // CRRESP[2] = PassDirty: peer has dirty data that needs writeback
                
                if (grant_w_s0 && s1_ace_crvalid) begin
                    if (s1_ace_crresp[2]) begin 
                        w_next_state = W_DATA_SNOOP; // Peer has dirty data
                    end 
                    else begin                 
                        w_next_state = W_MEM_REQ;    // Clean/Miss: proceed to memory
                    end
                end 
                else if (!grant_w_s0 && s0_ace_crvalid) begin
                    if (s0_ace_crresp[2]) begin
                        w_next_state = W_DATA_SNOOP; // Peer has dirty data
                    end 
                    else begin                  
                        w_next_state = W_MEM_REQ;    // Clean/Miss: proceed to memory
                    end 
                end
            end

            W_MEM_REQ: begin
                if (mem_awready) begin 
                    w_next_state = W_WAIT_B; 
                end
            end

            W_WAIT_B: begin
                if (mem_bvalid && mem_bready) begin
                    w_next_state = IDLE;
                end
            end

            W_DATA_SNOOP: begin
                // Ownership transfer: Peer sends dirty data
                // For writeback: just wait for peer to acknowledge
                if (grant_w_s0) begin
                    if (s1_ace_cdvalid) begin 
                        w_next_state = IDLE;
                    end
                end 
                else begin
                    if (s0_ace_cdvalid) begin 
                        w_next_state = IDLE;
                    end 
                end
            end
            default: w_next_state = IDLE;
        endcase
    end

    // ================================================================
    // SNOOP OUTPUT LOGIC (AC Channel)
    // ================================================================
    // Send snoop request to the OTHER core (not the requester)
    // grant_r_s0=1: Core 0 requesting -> snoop Core 1
    // grant_r_s0=0: Core 1 requesting -> snoop Core 0
    // ================================================================
    always @(*) begin
        s0_ace_acvalid  = 0; 
        s0_ace_acaddr   = 0; 
        s0_ace_acsnoop  = 0;
        s1_ace_acvalid  = 0; 
        s1_ace_acaddr   = 0; 
        s1_ace_acsnoop  = 0;
        
        // --- Snoop to CORE 0 (when Core 1 is requesting) ---
        if (!grant_r_s0 && r_state == SNOOP_REQ) begin
            s0_ace_acvalid  = 1'b1;
            s0_ace_acaddr   = s1_ar_addr;   // Address from Core 1's request
            s0_ace_acsnoop  = s1_ar_snoop;  // Snoop type from Core 1's request
        end 
        else if (!grant_w_s0 && w_state == SNOOP_REQ) begin
            // Writeback: no snoop needed (write-through)
            s0_ace_acvalid  = 1'b0; 
            s0_ace_acsnoop  = 4'b0000;
        end

        // --- Snoop to CORE 1 (when Core 0 is requesting) ---
        if (grant_r_s0 && r_state == SNOOP_REQ) begin
            s1_ace_acvalid  = 1'b1;
            s1_ace_acaddr   = s0_ar_addr;   // Address from Core 0's request
            s1_ace_acsnoop  = s0_ar_snoop;  // Snoop type from Core 0's request
        end 
        else if (grant_w_s0 && w_state == SNOOP_REQ) begin
            // Writeback: no snoop needed (write-through)
            s1_ace_acvalid  = 1'b0;
            s1_ace_acsnoop  = 4'b0000;
        end
    end

    // ================================================================
    // AXI MUX INSTANTIATION
    // ================================================================
    // Gate ready signals: only accept data when FSM is in correct state
    assign m0_rready_gated  = s0_axi_rready && (r_state == R_DATA_MEM);
    assign m1_rready_gated  = s1_axi_rready && (r_state == R_DATA_MEM);

    AXI_Master_Mux_R #(
        .ADDR_W (ADDR_W), 
        .DATA_W (DATA_W), 
        .ID_W   (ID_W)
    ) u_mux_r (
        .m0_arid    (s0_ar_id),
        .m0_araddr  (s0_ar_addr),
        .m0_arvalid (s0_pending_r && (r_state == R_MEM_REQ)), 
        .m0_arready (),                                         // khong dung mux arready cho nay
        .m0_rdata   (mux_s0_rdata),
        .m0_rid     (mux_s0_rid),
        .m0_rresp   (mux_s0_rresp),
        .m0_rvalid  (mux_s0_rvalid),
        .m0_rlast   (mux_s0_rlast),
        .m0_rready  (m0_rready_gated),

        .m1_arid    (s1_ar_id),
        .m1_araddr  (s1_ar_addr),
        .m1_arvalid (s1_pending_r && (r_state == R_MEM_REQ)),
        .m1_arready (),
        .m1_rdata   (mux_s1_rdata),
        .m1_rid     (mux_s1_rid),
        .m1_rresp   (mux_s1_rresp),
        .m1_rvalid  (mux_s1_rvalid),
        .m1_rlast   (mux_s1_rlast),
        .m1_rready  (m1_rready_gated),

        .s_arid     (mem_arid),
        .s_araddr   (mem_araddr),
        .s_arvalid  (mem_arvalid),
        .s_arready  (mem_arready),
        .s_rdata    (mem_rdata),
        .s_rid      (mem_rid),
        .s_rresp    (mem_rresp),
        .s_rvalid   (mem_rvalid),
        .s_rlast    (mem_rlast),
        .s_rready   (mem_rready),

        .m0_rgrnt   (grant_r_s0),
        .m1_rgrnt   (!grant_r_s0)
    );

    AXI_Master_Mux_W #(
        .ADDR_W (ADDR_W), 
        .DATA_W (DATA_W), 
        .ID_W   (ID_W)
    ) u_mux_w (
        .m0_awid    (s0_aw_id),
        .m0_awaddr  (s0_aw_addr),
        .m0_awvalid (s0_pending_w && (w_state == W_MEM_REQ)),
        .m0_awready (),                                         // khong dung mux awready cho nay
        .m0_wdata   (s0_axi_wdata), 
        .m0_wvalid  (s0_axi_wvalid && (w_state == W_MEM_REQ || w_state == W_WAIT_B)),
        .m0_wready  (s0_axi_wready),
        .m0_bvalid  (s0_axi_bvalid),
        .m0_bid     (s0_axi_bid),
        .m0_bresp   (s0_axi_bresp),
        .m0_bready  (s0_axi_bready),

        .m1_awid    (s1_aw_id),
        .m1_awaddr  (s1_aw_addr),
        .m1_awvalid (s1_pending_w && (w_state == W_MEM_REQ)),
        .m1_awready (),
        .m1_wdata   (s1_axi_wdata),
        .m1_wvalid  (s1_axi_wvalid && (w_state == W_MEM_REQ || w_state == W_WAIT_B)),
        .m1_wready  (s1_axi_wready),
        .m1_bvalid  (s1_axi_bvalid),
        .m1_bid     (s1_axi_bid),
        .m1_bresp   (s1_axi_bresp),
        .m1_bready  (s1_axi_bready),

        .s_awid     (mem_awid),
        .s_awaddr   (mem_awaddr),
        .s_awvalid  (mem_awvalid),
        .s_awready  (mem_awready),
        .s_wdata    (mem_wdata),
        .s_wvalid   (mem_wvalid),
        .s_wready   (mem_wready),
        .s_bvalid   (mem_bvalid),
        .s_bid      (mem_bid),
        .s_bresp    (mem_bresp),
        .s_bready   (mem_bready),

        .m0_wgrnt   (grant_w_s0),
        .m1_wgrnt   (!grant_w_s0)
    );
    
    // ================================================================
    // MEMORY BURST PARAMETERS
    // ================================================================
    // Mux burst parameters based on which core has grant
    assign mem_arlen    = grant_r_s0 ? s0_axi_arlen     : s1_axi_arlen;
    assign mem_arsize   = grant_r_s0 ? s0_axi_arsize    : s1_axi_arsize;
    assign mem_arburst  = grant_r_s0 ? s0_axi_arburst   : s1_axi_arburst;

    assign mem_awlen    = grant_w_s0 ? s0_axi_awlen     : s1_axi_awlen;
    assign mem_awsize   = grant_w_s0 ? s0_axi_awsize    : s1_axi_awsize;
    assign mem_awburst  = grant_w_s0 ? s0_axi_awburst   : s1_axi_awburst;
    assign mem_wstrb    = grant_w_s0 ? s0_axi_wstrb     : s1_axi_wstrb;
    assign mem_wlast    = grant_w_s0 ? s0_axi_wlast     : s1_axi_wlast;

endmodule