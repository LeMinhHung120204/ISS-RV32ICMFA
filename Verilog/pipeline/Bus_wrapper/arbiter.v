`timescale 1ns/1ps
// ============================================================================
// Arbiter - Round-Robin L1 Cache Arbiter for L2 Access
// ============================================================================
// Arbitrates between ICache (read-only) and DCache (read/write) requests.
// Uses alternating priority to ensure fairness.
// ============================================================================
module arbiter #(
    parameter ADDR_W        = 32,
    parameter CODE_START    = 32'h0000_0000, 
    parameter DATA_START    = 32'h0000_4000
)(
    input           clk, rst_n

    // --- Client 0: I-Cache (Read Only) ---
,   input                   i_c0_req_valid
,   input   [ADDR_W-1:0]    i_c0_req_addr
,   output  reg             o_c0_req_ready

    // --- Client 1: D-Cache (Read/Write) ---
,   input                   i_c1_req_valid
,   input   [1:0]           i_c1_req_cmd
,   input   [ADDR_W-1:0]    i_c1_req_addr
,   output  reg             o_c1_req_ready

    // --- Output to L2 Cache ---
,   input                       i_l2_ready
,   output  reg                 o_l2_valid
,   output  reg [1:0]           o_l2_cmd
,   output  reg [ADDR_W-1:0]    o_l2_addr
);

    // ================================================================
    // GRANT LOGIC - Priority-based selection
    // ================================================================
    reg priority_ptr;       // 0: ICache priority, 1: DCache priority
    reg grant_c0, grant_c1; // Grant signals

    always @(*) begin
        grant_c0 = 1'b0;
        grant_c1 = 1'b0;

        if (priority_ptr == 1'b0) begin // uu tien C0
            if (i_c0_req_valid) begin      
                grant_c0 = 1'b1;
            end 
            else if (i_c1_req_valid) begin 
                grant_c1 = 1'b1;
            end 
        end 
        else begin // uu tien C1
            if (i_c1_req_valid) begin      
                grant_c1 = 1'b1;
            end 
            else if (i_c0_req_valid) begin 
                grant_c0 = 1'b1;
            end 
        end
    end

    // ================================================================
    // OUTPUT MUX - Route selected request to L2
    // ================================================================
    always @(*) begin
        o_l2_valid      = 1'b0;
        o_l2_cmd        = 2'b00;
        o_l2_addr       = {ADDR_W{1'b0}};
        o_c0_req_ready  = 1'b0;
        o_c1_req_ready  = 1'b0;

        if (grant_c0) begin
            // ICache request: always ReadShared, add CODE_START offset
            o_l2_valid      = 1'b1;
            o_l2_cmd        = 2'b00;
            o_l2_addr       = CODE_START | i_c0_req_addr;
            o_c0_req_ready  = i_l2_ready; 
        end
        else if (grant_c1) begin
            // DCache request: pass command, add DATA_START offset
            o_l2_valid      = 1'b1;
            o_l2_cmd        = i_c1_req_cmd;
            o_l2_addr       = DATA_START | i_c1_req_addr;
            o_c1_req_ready  = i_l2_ready;
        end
    end

    // ================================================================
    // PRIORITY UPDATE - Alternate after each granted request
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            priority_ptr <= 1'b0;
        end 
        else begin
            // Flip priority after successful transaction
            if (o_l2_valid && i_l2_ready) begin
                if (grant_c0)      priority_ptr <= 1'b1;  // Next: DCache priority
                else if (grant_c1) priority_ptr <= 1'b0;  // Next: ICache priority
            end
        end
    end

endmodule