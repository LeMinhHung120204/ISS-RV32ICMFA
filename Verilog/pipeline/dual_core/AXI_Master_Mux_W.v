`timescale 1ns/1ns
// ============================================================================
// AXI Write Master Multiplexer (2:1)
// ============================================================================
//
// Multiplexes write requests from 2 masters to 1 slave.
// Uses external grant signals to select which master owns the bus.
//
// AW Channel (Address Write):
//   - Forwards awid, awaddr, awvalid from granted master
//   - Returns awready only to granted master
//
// W Channel (Write Data):
//   - Forwards wdata, wvalid from granted master
//   - Returns wready only to granted master
//
// B Channel (Write Response):
//   - Broadcasts bresp, bid to both masters
//   - Gates bvalid with grant signal
//   - Forwards bready from granted master only
//
// ============================================================================
module AXI_Master_Mux_W #(
    parameter ADDR_W = 32,
    parameter DATA_W = 64,
    parameter ID_W   = 2
) (
    // Master 0 AW/W/B
    input  [ID_W-1:0]   m0_awid
,   input  [ADDR_W-1:0] m0_awaddr
,   input               m0_awvalid
,   output              m0_awready
,   input  [DATA_W-1:0] m0_wdata
,   input               m0_wvalid
,   output              m0_wready
,   output              m0_bvalid
,   output [ID_W-1:0]   m0_bid
,   output [1:0]        m0_bresp
,   input               m0_bready
    // Master 1 AW/W/B
,   input  [ID_W-1:0]   m1_awid
,   input  [ADDR_W-1:0] m1_awaddr
,   input               m1_awvalid
,   output              m1_awready
,   input  [DATA_W-1:0] m1_wdata
,   input               m1_wvalid
,   output              m1_wready
,   output              m1_bvalid
,   output [ID_W-1:0]   m1_bid
,   output [1:0]        m1_bresp
,   input               m1_bready
    // Slave AW/W/B
,   output [ID_W-1:0]   s_awid
,   output [ADDR_W-1:0] s_awaddr
,   output              s_awvalid
,   input               s_awready
,   output [DATA_W-1:0] s_wdata
,   output              s_wvalid
,   input               s_wready
,   input               s_bvalid
,   input  [ID_W-1:0]   s_bid
,   input  [1:0]        s_bresp
,   output              s_bready
    // Grants
,   input               m0_wgrnt
,   input               m1_wgrnt
);

    // ================================================================
    // AW CHANNEL - Address Write Request
    // ================================================================
    assign s_awid       = m0_wgrnt ? m0_awid : m1_awid;
    assign s_awaddr     = m0_wgrnt ? m0_awaddr : m1_awaddr;
    assign s_awvalid    = m0_wgrnt ? m0_awvalid : m1_awvalid;
    assign m0_awready   = m0_wgrnt ? s_awready : 1'b0;
    assign m1_awready   = m1_wgrnt ? s_awready : 1'b0;

    // ================================================================
    // W CHANNEL - Write Data
    // ================================================================
    assign s_wdata      = m0_wgrnt ? m0_wdata : m1_wdata;
    assign s_wvalid     = m0_wgrnt ? m0_wvalid : m1_wvalid;
    assign m0_wready    = m0_wgrnt ? s_wready : 1'b0;
    assign m1_wready    = m1_wgrnt ? s_wready : 1'b0;

    // ================================================================
    // B CHANNEL - Write Response
    // ================================================================
    // Gate bvalid: only granted master sees valid response
    assign m0_bvalid    = s_bvalid & m0_wgrnt;
    assign m1_bvalid    = s_bvalid & m1_wgrnt;
    assign m0_bresp     = s_bresp;
    assign m1_bresp     = s_bresp;
    assign m0_bid       = s_bid;
    assign m1_bid       = s_bid;
    // Forward ready from granted master
    assign s_bready     = m0_wgrnt ? m0_bready : m1_bready;

endmodule
