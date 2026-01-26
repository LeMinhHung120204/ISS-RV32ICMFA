`timescale 1ns/1ps
module arbiter #(
    parameter ADDR_W        = 32,
    parameter CODE_START    = 32'h0000_0000, 
    parameter DATA_START    = 32'h0000_4000
)(
    input           clk, rst_n,

    // --- Client 0: I-Cache (Read Only) ---
    input                   i_c0_req_valid,
    input   [ADDR_W-1:0]    i_c0_req_addr,
    output  reg             o_c0_req_ready,

    // --- Client 1: D-Cache (Read/Write) ---
    input                   i_c1_req_valid,
    input   [1:0]           i_c1_req_cmd,
    input   [ADDR_W-1:0]    i_c1_req_addr,
    output  reg             o_c1_req_ready,

    // --- Output to L2 Cache ---
    input                       i_l2_ready,
    output  reg                 o_l2_valid,
    output  reg [1:0]           o_l2_cmd,
    output  reg [ADDR_W-1:0]    o_l2_addr
);

    reg priority_ptr;
    reg grant_c0, grant_c1;

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

    always @(*) begin
        o_l2_valid      = 1'b0;
        o_l2_cmd        = 2'b00;
        o_l2_addr       = {ADDR_W{1'b0}};
        o_c0_req_ready  = 1'b0;
        o_c1_req_ready  = 1'b0;

        if (grant_c0) begin
            o_l2_valid      = 1'b1;
            o_l2_cmd        = 2'b00; // I-Cache Read
            // o_l2_addr       = i_c0_req_addr;
            o_l2_addr       = CODE_START | i_c0_req_addr;

            // L2 Ready thi C0 cung Ready
            o_c0_req_ready  = i_l2_ready; 
        end
        else if (grant_c1) begin
            o_l2_valid      = 1'b1;
            o_l2_cmd        = i_c1_req_cmd;
            // o_l2_addr       = i_c1_req_addr;
            // o_l2_addr       = {4'h2, i_c1_req_addr[27:0]}; // phan vung icache va dcache
            o_l2_addr       = DATA_START | i_c1_req_addr;
    
            o_c1_req_ready  = i_l2_ready;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            priority_ptr <= 1'b0;
        end 
        else begin
            if (o_l2_valid && i_l2_ready) begin
                // Logic: dao bit nguoi thang
                if (grant_c0) begin      
                    priority_ptr <= 1'b1;
                end 
                else if (grant_c1) begin 
                    priority_ptr <= 1'b0;
                end 
            end
        end
    end

endmodule