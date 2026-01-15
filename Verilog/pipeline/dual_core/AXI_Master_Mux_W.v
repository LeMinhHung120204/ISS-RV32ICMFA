`timescale 1ns/1ns

// AXI Write master multiplexer for 2 masters -> 1 slave (AW, W, B channels)
module AXI_Master_Mux_W #(
    parameter ADDR_W = 32,
    parameter DATA_W = 64
) (
    input clk,
    // Master 0 AW/W/B
    input  [ADDR_W-1:0] m0_awaddr,
    input               m0_awvalid,
    output              m0_awready,
    input  [DATA_W-1:0] m0_wdata,
    input               m0_wvalid,
    output              m0_wready,
    output              m0_bvalid,
    output [1:0]        m0_bresp,
    input               m0_bready,
    // Master 1 AW/W/B
    input  [ADDR_W-1:0] m1_awaddr,
    input               m1_awvalid,
    output              m1_awready,
    input  [DATA_W-1:0] m1_wdata,
    input               m1_wvalid,
    output              m1_wready,
    output              m1_bvalid,
    output [1:0]        m1_bresp,
    input               m1_bready,
    // Slave AW/W/B
    output [ADDR_W-1:0] s_awaddr,
    output              s_awvalid,
    input               s_awready,
    output [DATA_W-1:0] s_wdata,
    output              s_wvalid,
    input               s_wready,
    input               s_bvalid,
    input  [1:0]        s_bresp,
    output              s_bready,
    // Grants
    input               m0_wgrnt,
    input               m1_wgrnt
);

    // AW channel
    assign s_awaddr     = m0_wgrnt ? m0_awaddr : m1_awaddr;
    assign s_awvalid    = m0_wgrnt ? m0_awvalid : m1_awvalid;
    assign m0_awready   = m0_wgrnt ? s_awready : 1'b0;
    assign m1_awready   = m1_wgrnt ? s_awready : 1'b0;

    // W channel
    assign s_wdata      = m0_wgrnt ? m0_wdata : m1_wdata;
    assign s_wvalid     = m0_wgrnt ? m0_wvalid : m1_wvalid;
    assign m0_wready    = m0_wgrnt ? s_wready : 1'b0;
    assign m1_wready    = m1_wgrnt ? s_wready : 1'b0;

    // B channel: route response back to the correct master
    assign m0_bvalid    = s_bvalid & m0_wgrnt;
    assign m1_bvalid    = s_bvalid & m1_wgrnt;
    assign m0_bresp     = s_bresp;
    assign m1_bresp     = s_bresp;
    assign s_bready     = m0_wgrnt ? m0_bready : m1_bready;

endmodule
