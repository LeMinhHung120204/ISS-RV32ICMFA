`timescale 1ns/1ps
// from Lee Min Hunz with luv
// ============================================================================
// ICache Controller - Instruction Cache FSM
// ============================================================================
//
// Controls L1 instruction cache operations. Read-only cache with
// simple refill logic (no writeback needed).
//
// State Descriptions:
//   TAG_CHECK  : Compare tag, check hit/miss
//   ALLOC_REQ  : Send refill request to L2
//   ALLOC_WAIT : Wait for L2 data response
//   UPDATE     : Write refill data to cache RAM
//   WAIT_RAM   : Wait one cycle for SRAM write to complete
//
// ============================================================================
module icache_controller #(
    parameter DATA_W    = 32,
    parameter ADDR_W    = 32
)(
    input               clk, rst_n

    // Cache <-> CPU
,   input               cpu_req
,   input               hit               

,   output  reg         tag_we 
,   output  reg         refill_we
,   output  reg         stall
,   output  reg         read_index_src
   
    // request L1 -> L2 
,   input           i_mem_req_ready // L2 san sang nhan
,   output  reg     o_mem_req_valid // Bao co request

    // read data L2 -> L1
,   input           i_mem_rdata_valid
    // input           i_mem_rdata_last,
,   output  reg     o_mem_rdata_ready
);

    // ================================================================
    // LOCAL PARAMETERS - FSM State Encoding
    // ================================================================
    localparam TAG_CHECK    = 4'd0;   // Check tag for hit/miss
    localparam ALLOC_REQ    = 4'd1;   // Send refill request to L2
    localparam ALLOC_WAIT   = 4'd2;   // Wait for L2 data
    localparam UPDATE       = 4'd3;   // Write data to cache
    localparam WAIT_RAM     = 4'd4;   // Wait one cycle for SRAM write

    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    reg [3:0] state, next_state;

    // ================================================================
    // STATE REGISTER
    // ================================================================

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= TAG_CHECK;
        end 
        else begin       
            state <= next_state;
        end
    end

    // ================================================================
    // NEXT STATE LOGIC
    // ================================================================
    // Simple miss handling: request -> wait -> update -> done
    // ================================================================
    always @(*) begin
        next_state = state;
        case(state)
            TAG_CHECK: begin
                // On miss, initiate refill from L2
                if (cpu_req) begin
                    if (hit) begin
                        next_state = TAG_CHECK;     // Hit: serve immediately
                    end 
                    else begin
                        next_state = ALLOC_REQ;     // Miss: fetch from L2
                    end
                end
            end

            // --------------------------------------------------------
            // REFILL FLOW: Request -> Wait -> Update -> Done
            // --------------------------------------------------------
            ALLOC_REQ: begin
                // Send address to L2, wait for ready
                if (i_mem_req_ready) begin
                    next_state = ALLOC_WAIT;
                end 
            end
            
            ALLOC_WAIT: begin
                // Wait for L2 to return cache line
                if (i_mem_rdata_valid) begin
                    next_state = UPDATE;
                end
            end

            UPDATE: begin
                // Write received data to cache RAM
                next_state = WAIT_RAM;
            end

            WAIT_RAM: begin
                // Wait one cycle for SRAM write completion
                next_state = TAG_CHECK;
            end 

            default: next_state = TAG_CHECK;
        endcase
    end

    // ================================================================
    // OUTPUT LOGIC
    // ================================================================
    // Generate control signals based on current state
    // ================================================================
    always @(*) begin
        // Default: no activity
        o_mem_req_valid     = 1'b0;
        o_mem_rdata_ready   = 1'b0;
        tag_we              = 1'b0;
        stall               = 1'b0;
        refill_we           = 1'b0;
        read_index_src      = 1'b0;     // 0=S2 index, 1=S1 index

        case(state)
            ALLOC_REQ: begin
                o_mem_req_valid = 1'b1; // Request refill from L2
            end

            ALLOC_WAIT: begin
                o_mem_req_valid     = 1'b1; // Keep request active
                o_mem_rdata_ready   = 1'b1; // Ready to receive data
            end

            UPDATE: begin
                tag_we      = 1'b1;     // Write new tag
                refill_we   = 1'b1;     // Write refill data to RAM
            end

            WAIT_RAM: begin
                stall           = 1'b1; // Hold pipeline
                read_index_src  = 1'b1; // Use S1 index for next lookup
            end 
        endcase
    end

endmodule