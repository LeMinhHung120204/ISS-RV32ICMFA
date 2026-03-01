`timescale 1ns/1ns
// ============================================================================
// AXI Read Master Multiplexer (2:1)
// ============================================================================
//
// Multiplexes read requests from 2 masters to 1 slave.
// Uses external grant signals to select which master owns the bus.
//
// Data Flow:
//   Master 0 ───┬───> MUX ───> Slave (Memory)
//   Master 1 ───┘       <───  (Read Data)
//
// AR Channel (Address Read):
//   - Forwards arid, araddr, arvalid from granted master
//   - Returns arready only to granted master
//
// R Channel (Read Data):
//   - Broadcasts rdata, rid, rresp to both masters
//   - Gates rvalid, rlast with grant signal
//   - Forwards rready from granted master only
//
// ============================================================================
module AXI_Master_Mux_R #(
    parameter ADDR_W = 32,
    parameter DATA_W = 64,
    parameter ID_W   = 2
) (
    // Master 0 AR/R
    input   [ID_W-1:0]      m0_arid
,   input   [ADDR_W-1:0]    m0_araddr
,   input                   m0_arvalid
,   output                  m0_arready
,   output  [DATA_W-1:0]    m0_rdata
,   output  [ID_W-1:0]      m0_rid
,   output  [3:0]           m0_rresp
,   output                  m0_rvalid
,   output                  m0_rlast
,   input                   m0_rready
    // Master 1 AR/R
,   input   [ID_W-1:0]      m1_arid
,   input   [ADDR_W-1:0]    m1_araddr
,   input                   m1_arvalid
,   output                  m1_arready
,   output  [DATA_W-1:0]    m1_rdata
,   output  [ID_W-1:0]      m1_rid
,   output  [3:0]           m1_rresp
,   output                  m1_rvalid
,   output                  m1_rlast
,   input                   m1_rready
    // Slave AR/R
,   output  [ID_W-1:0]      s_arid
,   output  [ADDR_W-1:0]    s_araddr
,   output                  s_arvalid
,   input                   s_arready
,   input   [DATA_W-1:0]    s_rdata
,   input   [ID_W-1:0]      s_rid
,   input   [3:0]           s_rresp
,   input                   s_rvalid
,   input                   s_rlast
,   output                  s_rready
    // Grants
,   input                   m0_rgrnt
,   input                   m1_rgrnt
);

    // ================================================================
    // AR CHANNEL - Address Read Request
    // ================================================================
    // Select address/id from granted master
    assign s_arid       = m0_rgrnt ? m0_arid : m1_arid;
    assign s_araddr     = m0_rgrnt ? m0_araddr : m1_araddr;
    assign s_arvalid    = m0_rgrnt ? m0_arvalid : m1_arvalid;
    // Only granted master sees arready
    assign m0_arready   = m0_rgrnt ? s_arready : 1'b0;
    assign m1_arready   = m1_rgrnt ? s_arready : 1'b0;

    // ================================================================
    // R CHANNEL - Read Data Response
    // ================================================================
    // Broadcast data to both (masters check rvalid)
    assign m0_rdata     = s_rdata;
    assign m1_rdata     = s_rdata;
    assign m0_rid       = s_rid;
    assign m1_rid       = s_rid;
    assign m0_rresp     = s_rresp;
    assign m1_rresp     = s_rresp;
    // Gate valid/last with grant (only granted master sees valid data)
    assign m0_rvalid    = s_rvalid & m0_rgrnt;
    assign m1_rvalid    = s_rvalid & m1_rgrnt;
    assign m0_rlast     = s_rlast  & m0_rgrnt;
    assign m1_rlast     = s_rlast  & m1_rgrnt;
    // Forward ready from granted master
    assign s_rready     = m0_rgrnt ? m0_rready : m1_rready;

endmodule
