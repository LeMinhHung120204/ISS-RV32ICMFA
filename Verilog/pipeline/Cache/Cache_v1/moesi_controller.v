`timescale 1ns/1ps
// ============================================================================
// MOESI State Controller - Cache Coherence State Machine
// ============================================================================
//
// Implements the MOESI cache coherence protocol state transitions.
// Handles state changes from CPU requests, bus snoops, and refill operations.
//
// State Transitions:
//   CPU Read Miss:  I -> E (if unique) or S (if shared)
//   CPU Write Miss: I -> M (if unique) or via Upgrade
//   CPU Write Hit:  S/E/O -> M
//   Snoop Read:     M/E -> O/S (downgrade, share data)
//   Snoop Write:    Any -> I (invalidate)
//
// ============================================================================
module moesi_controller(
    input   [2:0]   current_state
,   input           is_shared_response
,   input           is_dirty_response
,   input           refill_we

    // Request from CPU 
,   input           cpu_req_valid
,   input           cpu_hit
,   input           cpu_rw         // 1: Write, 0: Read

    // Request from Bus (Snoop)
,   input           bus_snoop_valid
,   input           snoop_hit      
,   input           bus_rw      
,   input           l1_dirty   

    // Outputs
,   output              is_dirty       
,   output              is_unique      
,   output              is_owner       
,   output              is_valid       
,   output reg [2:0]    next_state
);

    // ================================================================
    // LOCAL PARAMETERS - MOESI State Encoding
    // ================================================================
    localparam  STATE_M = 3'd0,   // Modified  - Dirty, Exclusive
                STATE_O = 3'd1,   // Owned     - Dirty, Shared
                STATE_E = 3'd2,   // Exclusive - Clean, Exclusive
                STATE_S = 3'd3,   // Shared    - Clean, Shared
                STATE_I = 3'd4;   // Invalid

    // ================================================================
    // STATE DECODE LOGIC
    // ================================================================
    // Extract state properties for external use
    assign is_dirty     = (current_state == STATE_M) | (current_state == STATE_O);  // Has dirty data
    assign is_unique    = (current_state == STATE_M) | (current_state == STATE_E);  // Only copy
    assign is_owner     = (current_state == STATE_M) | (current_state == STATE_O);  // Responsible for data
    assign is_valid     = (current_state != STATE_I);                               // Has valid copy

    // ================================================================
    // NEXT STATE LOGIC
    // ================================================================
    always @(*) begin
        next_state = current_state;
        // ========================
        // SNOOP REQUEST HANDLING (Highest Priority)
        // ========================
        // External core wants access to this cache line
        if (bus_snoop_valid && snoop_hit) begin
            if (bus_rw) begin   // Bus Write (CleanInvalid/MakeInvalid)
                // Other core wants exclusive access -> Invalidate our copy
                next_state = STATE_I; 
            end
            else begin // Bus Read (ReadShared)
                // Other core wants to read -> Downgrade to shared
                case (current_state)
                    STATE_M, STATE_O:   next_state = STATE_O; // Keep ownership of dirty data
                    STATE_E: begin            
                        if (l1_dirty) begin 
                            next_state = STATE_O; // L1 modified -> Owned (dirty shared)
                        end 
                        else begin
                            next_state = STATE_S; // L1 clean -> Shared
                        end 
                    end 
                    STATE_S:            next_state = STATE_S; // Already shared
                    default:            next_state = STATE_I;
                endcase
            end
        end

        // ========================
        // REFILL HANDLING (Cache Miss Resolution)
        // ========================
        // Data received from memory or peer cache
        else if (refill_we) begin
            if (is_dirty_response) begin
                // Received dirty data from peer cache (cache-to-cache transfer)
                if (is_shared_response) 
                    next_state = STATE_O; // Dirty + Shared -> Owned (share dirty line)
                else 
                    next_state = STATE_M; // Dirty + Unique -> Modified (got exclusive dirty)
            end
            else begin
                // Received clean data from memory or peer cache
                if (is_shared_response) 
                    next_state = STATE_S; // Clean + Shared -> Shared
                else      
                    next_state = STATE_E; // Clean + Unique -> Exclusive (only copy)
            end
        end

        // ========================
        // CPU HIT HANDLING (Local Access)
        // ========================
        // CPU accessing a line that exists in cache
        else if (cpu_req_valid && cpu_hit) begin
            if (cpu_rw) begin // Write Hit -> Always upgrade to Modified
                next_state = STATE_M; 
            end 
            else begin // Read Hit -> Keep current state
                next_state = current_state; 
            end 
        end 
    end 
endmodule