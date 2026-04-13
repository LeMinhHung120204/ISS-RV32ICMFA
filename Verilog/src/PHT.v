`timescale 1ns / 1ps
// from Lee Min Hunz with luv
// ============================================================================
// PHT - Pattern History Table (GShare Predictor)
// ============================================================================
// 8 entries indexed by PC XOR Global History (GHSR).
// 2-bit saturating counter per entry: 00=SNT, 01=WNT, 10=WT, 11=ST
// Updates GHSR and counter on branch resolution in EX stage.
// ============================================================================
module PHT(
    input           clk, rst_n
,   input           E_Branch
,   input           E_Jump
,   input           Taken        // 1 if taken, 0 if not taken
,   input [2:0]     F_PC   
,   input [2:0]     E_PC 
,   input [2:0]     E_GHSR   

,   output          predict
,   output [2:0]    GHSR_out
);
    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    reg [2:0] GHSR;                     // Global History Shift Register
    reg [1:0] next_state;               // Next counter state
    reg [1:0] state [0:7];              // 2-bit counters (8 entries)

    // ================================================================
    // INDEX COMPUTATION - GShare: PC XOR GHSR
    // ================================================================
    wire [2:0]  read_index      = F_PC ^ GHSR;      // Fetch stage lookup
    wire [2:0]  write_index     = E_PC ^ E_GHSR;    // EX stage update
    wire [1:0]  current_state   = state[read_index]; 
    wire [1:0]  E_State         = state[write_index];
    wire        final_taken     = Taken | E_Jump;   // Jumps always taken

    // Predict taken if counter MSB is 1 (WT or ST)
    assign predict  = current_state[1];
    assign GHSR_out = GHSR;

    // ================================================================
    // 2-BIT SATURATING COUNTER - State transition
    // ================================================================
    // 00 (SNT) -> 01 (WNT) -> 10 (WT) -> 11 (ST)
    always @(*) begin
        case(E_State)
            2'b00: next_state = final_taken ? 2'b01 : 2'b00; // SNT: inc if taken
            2'b01: next_state = final_taken ? 2'b10 : 2'b00; // WNT: inc/dec
            2'b10: next_state = final_taken ? 2'b11 : 2'b01; // WT: inc/dec
            2'b11: next_state = final_taken ? 2'b11 : 2'b10; // ST: dec if not taken
        endcase
    end

    // ================================================================
    // UPDATE LOGIC - Update GHSR and counter on branch/jump
    // ================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            GHSR <= 3'b000;
            for(i = 0; i < 8; i = i + 1) 
                state[i] <= 2'b10; // Init as Weakly Taken
        end
        else begin
            if(E_Branch | E_Jump) begin
                // Shift in outcome to GHSR
                GHSR <= {GHSR[1:0], final_taken};
                // Update 2-bit counter
                state[write_index] <= next_state;
            end
        end
    end
endmodule