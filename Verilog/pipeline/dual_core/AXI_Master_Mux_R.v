`timescale 1ns/1ns

// AXI Read master multiplexer for 2 masters -> 1 slave
module AXI_Master_Mux_R #(
    parameter ADDR_W = 32,
    parameter DATA_W = 64
) (
    input clk,
    // Master 0 AR/R
    input   [ADDR_W-1:0]    m0_araddr,
    input                   m0_arvalid,
    output                  m0_arready,
    output  [DATA_W-1:0]    m0_rdata,
    output                  m0_rvalid,
    output                  m0_rlast,
    input                   m0_rready,
    // Master 1 AR/R
    input   [ADDR_W-1:0]    m1_araddr,
    input                   m1_arvalid,
    output                  m1_arready,
    output  [DATA_W-1:0]    m1_rdata,
    output                  m1_rvalid,
    output                  m1_rlast,
    input                   m1_rready,
    // Slave AR/R
    output  [ADDR_W-1:0]    s_araddr,
    output                  s_arvalid,
    input                   s_arready,
    input   [DATA_W-1:0]    s_rdata,
    input                   s_rvalid,
    input                   s_rlast,
    output                  s_rready,
    // Grants
    input                   m0_rgrnt,
    input                   m1_rgrnt
);

    // AR channel: forward address/valid and ready
    assign s_araddr     = m0_rgrnt ? m0_araddr : m1_araddr;
    assign s_arvalid    = m0_rgrnt ? m0_arvalid : m1_arvalid;
    assign m0_arready   = m0_rgrnt ? s_arready : 1'b0;
    assign m1_arready   = m1_rgrnt ? s_arready : 1'b0;

    // R channel: route slave responses back to granted master
    assign m0_rdata     = s_rdata;
    assign m1_rdata     = s_rdata;
    assign m0_rvalid    = s_rvalid & m0_rgrnt;
    assign m1_rvalid    = s_rvalid & m1_rgrnt;
    assign m0_rlast     = s_rlast  & m0_rgrnt;
    assign m1_rlast     = s_rlast  & m1_rgrnt;
    assign s_rready     = m0_rgrnt ? m0_rready : m1_rready;

endmodule
