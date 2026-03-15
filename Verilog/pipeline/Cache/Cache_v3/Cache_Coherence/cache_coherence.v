`timescale 1ns/1ps

module coherence_interconnect #(
    parameter ADDR_W = 32,
    parameter LINE_W = 128 // (4 words * 32 bits)
)(
    input clk
,   input rst_n

    // ==========================================
    // PORT CORE 0
    // ==========================================
    // --- I-Cache 0 Interface ---
    // request
,   input                   i_ic0_req_valid
,   output                  o_ic0_req_ready
,   input   [ADDR_W-1:0]    i_ic0_req_addr
    // response
,   input                   i_ic0_rdata_ready
,   output                  o_ic0_rdata_valid
,   output  [LINE_W-1:0]    o_ic0_rdata

    // --- D-Cache 0 Request/Response ---
    // Request
,   input                   i_dc0_req_valid
,   output                  o_dc0_req_ready
,   input   [ADDR_W-1:0]    i_dc0_req_addr
,   input   [1:0]           i_dc0_req_cmd    
,   input   [LINE_W-1:0]    i_dc0_req_data
,   input                   i_dc0_req_wb 

    // Response
,   input                   i_dc0_resp_ready
,   output                  o_dc0_resp_valid
,   output  [LINE_W-1:0]    o_dc0_resp_data
    
    // --- D-Cache 0 Snoop Bus ---
    // Snoop Request
,   input                   i_dc0_snp_req_ready
,   output                  o_dc0_snp_req_valid
,   output  [ADDR_W-1:0]    o_dc0_snp_req_addr
,   output  [1:0]           o_dc0_snp_req_cmd
,   output                  o_dc0_resp_is_shared // Cờ MOESI báo về D-Cache 0
,   output                  o_dc0_resp_is_dirty  // Cờ MOESI báo về D-Cache 0

    // Information snooping response từ D-Cache 0
,   input                   i_dc0_snp_resp_valid
,   input                   i_dc0_snp_resp_hit
,   input   [LINE_W-1:0]    i_dc0_snp_resp_data

    // ==========================================
    // PORT CORE 1
    // ==========================================
    // --- I-Cache 1 Interface ---
    // request
,   input                   i_ic1_req_valid
,   output                  o_ic1_req_ready
,   input   [ADDR_W-1:0]    i_ic1_req_addr
    // response
,   input                   i_ic1_rdata_ready
,   output                  o_ic1_rdata_valid
,   output  [LINE_W-1:0]    o_ic1_rdata

    // --- D-Cache 1 Request/Response ---
    // Request
,   input                   i_dc1_req_valid
,   output                  o_dc1_req_ready
,   input   [ADDR_W-1:0]    i_dc1_req_addr
,   input   [1:0]           i_dc1_req_cmd    
,   input   [LINE_W-1:0]    i_dc1_req_data
,   input                   i_dc1_req_wb 

    // Response
,   input                   i_dc1_resp_ready
,   output                  o_dc1_resp_valid
,   output  [LINE_W-1:0]    o_dc1_resp_data
    
    // --- D-Cache 1 Snoop Bus ---
    // Snoop Request
,   input                   i_dc1_snp_req_ready
,   output                  o_dc1_snp_req_valid
,   output  [ADDR_W-1:0]    o_dc1_snp_req_addr
,   output  [1:0]           o_dc1_snp_req_cmd
,   output                  o_dc1_resp_is_shared // Cờ MOESI báo về D-Cache 1
,   output                  o_dc1_resp_is_dirty  // Cờ MOESI báo về D-Cache 1

    // Information snooping response từ D-Cache 1
,   input                   i_dc1_snp_resp_valid
,   input                   i_dc1_snp_resp_hit
,   input   [LINE_W-1:0]    i_dc1_snp_resp_data

    // ==========================================
    // PORT L2 CACHE (Shared)
    // ==========================================
,   output                  o_l2_req_valid
,   input                   i_l2_req_ready
,   output  [ADDR_W-1:0]    o_l2_req_addr
,   output                  o_l2_req_rw      // 0: Read, 1: Write
,   output  [LINE_W-1:0]    o_l2_req_wdata
,   input                   i_l2_resp_valid
,   output                  o_l2_resp_ready
,   input   [LINE_W-1:0]    i_l2_resp_rdata

);
    
endmodule 