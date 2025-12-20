`timescale 1ns/1ps
module moesi_controller(
    input   [2:0]   current_state,
    input           is_shared_response,
    input           is_dirty_response,

    // Request from CPU 
    input           cpu_req_valid,
    input           cpu_hit,
    input           cpu_rw,         // 1: Write, 0: Read

    // Request from Bus 
    input           bus_snoop_valid,
    input           snoop_hit,      
    input           bus_rw,         

    // Outputs
    output          is_dirty,       // Bao cho Snoop/WB: Can write back data
    output          is_unique,      // Bao cho Snoop: dang giu doc quyen (M/E)
    output          is_owner,       // Bao cho Snoop: dang la Owner (M/O)
    output          is_valid,       // Bao cho Snoop: Dong nay co hop le (khong phai I)
    output reg [2:0] next_state
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

    // --- Next State Logic ---
    always @(*) begin
        next_state = current_state; 
        // SNOOP REQUEST
        if (bus_snoop_valid && snoop_hit) begin
            if (bus_rw) begin 
                next_state = STATE_I; 
            end
            else begin 
                case (current_state)
                    STATE_M, STATE_O: begin
                        next_state = STATE_O; 
                    end
                    STATE_E: begin
                        next_state = STATE_S;
                    end
                    STATE_S: begin
                        next_state = STATE_S;
                    end
                    default: next_state = STATE_I;
                endcase
            end
        end

        // CPU REQUEST
        else if (cpu_req_valid) begin
            if (cpu_hit) begin
                if (cpu_rw) begin // Write Hit
                    next_state = STATE_M; 
                end 
                else begin // Read Hit
                    next_state = current_state; 
                end 
            end 
            else begin
                if (cpu_rw) begin 
                    // Write Miss: Ghi de len dong moi nap -> Modified
                    next_state = STATE_M; 
                end
                if (is_dirty_response) begin
                        // Nhan du lieu Dirty tu cache khac
                        if (is_shared_response) 
                            next_state = STATE_O; // Dirty + Shared -> Owned
                        else 
                            next_state = STATE_M; // Dirty + Unique -> Modified
                    end 
                else begin
                    // Nhan du lieu Clean (tu RAM hoac cache khac)
                    if (is_shared_response) 
                        next_state = STATE_S; // Clean + Shared -> Shared
                    else      
                        next_state = STATE_E; // Clean + Unique -> Exclusive
                end
            end
        end
    end 
endmodule