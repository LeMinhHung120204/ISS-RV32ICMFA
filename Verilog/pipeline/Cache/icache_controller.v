`timescale 1ns/1ps
module icache_controller #(
    parameter DATA_W    = 32,
    parameter ADDR_W    = 32,
    parameter BURST_LEN = 15 // 16 words = 64 bytes cache line
)(
    input               clk, rst_n,

    // Cache <-> CPU
    input               cpu_req,
    input               hit,               

    output  reg         tag_we, 
    output  reg         refill_we,
    output  reg [3:0]   burst_cnt,

   
    // request L1 -> L2 
    input           i_mem_req_ready, // L2 san sang nhan
    output  reg     o_mem_req_valid, // Bao co request

    // read data L2 -> L1
    input           i_mem_rdata_valid,
    // input           i_mem_rdata_last,
    output  reg     o_mem_rdata_ready
);

    // State Encoding
    localparam IDLE         = 4'd0;
    localparam TAG_CHECK    = 4'd1;
    localparam ALLOC_REQ    = 4'd2;
    localparam ALLOC_WAIT   = 4'd3;
    localparam UPDATE       = 4'd4;
    localparam WAIT_RAM     = 4'd5;

    reg [3:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            burst_cnt <= 4'd0;
        end 
        else begin
            if (state == ALLOC_WAIT && i_mem_rdata_valid) begin
                burst_cnt <= burst_cnt + 1'b1;
            end 
            else if (state != ALLOC_WAIT) begin
                burst_cnt <= 4'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= TAG_CHECK;
        end 
        else begin       
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            TAG_CHECK: begin
                if (cpu_req) begin
                    if (hit) begin
                        next_state = TAG_CHECK;
                    end 
                    else begin
                        next_state = ALLOC_REQ; // Clean -> Read L2
                    end
                end
            end

            // --- ALLOCATION FLOW (REFILL) ---
            ALLOC_REQ: begin
                // Gui request address len cache L2
                if (i_mem_req_ready) begin
                    next_state = ALLOC_WAIT;
                end 
            end
            ALLOC_WAIT: begin
                // Nhan Data vao refill buffer
                if (i_mem_rdata_valid) begin
                    next_state = UPDATE;
                end
            end

            UPDATE: begin
                // ghi refill buffer vao cache
                next_state = WAIT_RAM;
            end

            WAIT_RAM: begin
                // cho 1 cky de ghi
                next_state = TAG_CHECK;
            end 
            default: next_state = TAG_CHECK;
        endcase
    end

    always @(*) begin
        o_mem_req_valid     = 1'b0;
        o_mem_rdata_ready   = 1'b0;
        tag_we              = 1'b0;
        refill_we           = 1'b0;

        case(state)
            ALLOC_REQ: begin
                o_mem_req_valid = 1'b1;
            end

            ALLOC_WAIT: begin
                o_mem_rdata_ready = 1'b1; // san sang nhan data vao refill buffer
            end

            UPDATE: begin
                tag_we      = 1'b1;
                refill_we   = 1'b1;
            end
        endcase
    end

endmodule