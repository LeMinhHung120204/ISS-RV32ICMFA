`timescale 1ns / 1ps
// Pattern History Table
// GShare Predictor
// 8 entries, 2-bit saturating counter
// From Lee Min Hunz with love
module PHT(
    input           clk, rst_n,
    input           E_branch,
    input           E_jump,
    input           Taken,        // 1 if taken, 0 if not taken
    input [2:0]     F_PC,   
    input [2:0]     E_PC, 
    input [2:0]     E_GHSR,   

    output          predict,
    output [2:0]    GHSR_out
);
    reg [2:0] GHSR;
    reg [1:0] next_state;
    reg [1:0] state [0:7];

    wire [2:0]  read_index      = F_PC ^ GHSR; 
    wire [2:0]  write_index     = E_PC ^ E_GHSR;
    wire [1:0]  current_state   = state[read_index]; 
    wire [1:0]  E_State         = state[write_index];
    wire        final_taken     = Taken | E_jump;

    assign predict  = current_state[1];
    assign GHSR_out = GHSR;

    always @(*) begin
        case(E_State)
            2'b00: next_state = final_taken ? 2'b01 : 2'b00; // Strong NT -> Weak NT (nếu sai)
            2'b01: next_state = final_taken ? 2'b10 : 2'b00; // Weak NT -> Weak taken (nếu sai)
            2'b10: next_state = final_taken ? 2'b11 : 2'b01; // Weak taken -> Weak NT (nếu sai)
            2'b11: next_state = final_taken ? 2'b11 : 2'b10; // Strong taken -> Weak taken (nếu sai)
        endcase
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            GHSR <= 3'b000;
            for(i = 0; i < 8; i = i + 1) 
                state[i] <= 2'b10; // Init Weakly taken
        end
        else begin
            if(E_branch | E_jump) begin
                // Cap nhat Global History
                GHSR <= {GHSR[1:0], final_taken};
                
                // Cap nhat PHT
                state[write_index] <= next_state;
            end
        end
    end
endmodule