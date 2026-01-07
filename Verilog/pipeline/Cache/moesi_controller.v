`timescale 1ns/1ps
module moesi_controller(
    input   [2:0]   current_state,
    input           is_shared_response,
    input           is_dirty_response,
    input           refill_we,

    // Request from CPU 
    input           cpu_req_valid,
    input           cpu_hit,
    input           cpu_rw,         // 1: Write, 0: Read

    // Request from Bus (Snoop)
    input           bus_snoop_valid,
    input           snoop_hit,      
    input           bus_rw,         

    // Outputs
    output              is_dirty,       
    output              is_unique,      
    output              is_owner,       
    output              is_valid,       
    output reg [2:0]    next_state
);
    localparam  STATE_M = 3'd0,
                STATE_O = 3'd1,
                STATE_E = 3'd2,
                STATE_S = 3'd3,
                STATE_I = 3'd4;
    
    assign is_dirty     = (current_state == STATE_M) | (current_state == STATE_O);
    assign is_unique    = (current_state == STATE_M) | (current_state == STATE_E);
    assign is_owner     = (current_state == STATE_M) | (current_state == STATE_O);
    assign is_valid     = (current_state != STATE_I);

    always @(*) begin
        next_state = current_state;
        // SNOOP REQUEST
        if (bus_snoop_valid && snoop_hit) begin
            if (bus_rw) begin   // Bus write
                next_state = STATE_I; 
            end
            else begin // Bus read (ReadShared)
                case (current_state)
                    STATE_M, STATE_O:   next_state = STATE_O; // Chia se du lieu Dirty -> Owned
                    STATE_E:            next_state = STATE_S; // E -> S
                    STATE_S:            next_state = STATE_S;
                    default:            next_state = STATE_I;
                endcase
            end
        end

        // REFILL
        else if (refill_we) begin
            if (is_dirty_response) begin
                // Nhan data Dirty ty Cache khac
                if (is_shared_response) 
                    next_state = STATE_O; // Dirty + Shared -> Owned
                else 
                    next_state = STATE_M; // Dirty + Unique -> Modified
            end
            else begin
                // Nhan data Clean tu RAM hoac Cache khac
                if (is_shared_response) 
                    next_state = STATE_S; // Clean + Shared -> Shared
                else      
                    next_state = STATE_E; // Clean + Unique -> Exclusive
            end
        end

        // CPU HIT (Xu ly Hit)
        else if (cpu_req_valid && cpu_hit) begin
            if (cpu_rw) begin // Write Hit
                next_state = STATE_M; 
            end 
            else begin // Read Hit
                next_state = current_state; 
            end 
        end 
    end 
endmodule