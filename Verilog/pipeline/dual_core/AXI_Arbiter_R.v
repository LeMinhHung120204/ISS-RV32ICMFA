`timescale 1ns/1ns
// ============================================================================
// AXI Read Channel Arbiter (2-Master Round-Robin)
// ============================================================================
//
// Arbitrates read channel access between 2 masters using round-robin policy.
// Grant is held until current transaction completes (RLAST asserted).
//
// Arbitration Policy:
//   - If both masters request: alternate based on last grant
//   - If only one requests: grant immediately
//   - Switch grant on RLAST (end of burst) or when current master idle
//
// State Encoding:
//   cur = M0: Master 0 has grant
//   cur = M1: Master 1 has grant
//
// ============================================================================
module AXI_Arbiter_R (
    input  ACLK
,   input  ARESETn
    // Master request signals
,   input  m0_ARVALID       // Master 0 has read request
,   input  m0_RREADY        // Master 0 ready to receive
,   input  m1_ARVALID       // Master 1 has read request
,   input  m1_RREADY        // Master 1 ready to receive
    // Slave response signals  
,   input  s_RVALID         // Slave has valid data
,   input  s_RLAST          // Last beat of burst
    // Grant outputs
,   output reg m0_rgrnt     // Master 0 granted
,   output reg m1_rgrnt     // Master 1 granted
);

    // ================================================================
    // LOCAL PARAMETERS
    // ================================================================
    parameter M0 = 1'b0;        // Grant to Master 0
    parameter M1 = 1'b1;        // Grant to Master 1
    
    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    reg cur;                    // Current grant holder

    // ================================================================
    // ARBITRATION LOGIC
    // ================================================================
    // Switch grant when:
    //   1. Current transaction ends (RLAST) AND other master waiting, OR
    //   2. Current master idle AND other master requesting
    // ================================================================
    always @(posedge ACLK or negedge ARESETn) begin
		if (!ARESETn) begin
			cur <= M0;
		end 
		else begin
			case (cur)
				M0: begin
					// if (m0_ARVALID) begin 
					// 	cur <= M0;
					// end
					// else if ((s_RLAST && s_RVALID) || m1_ARVALID) begin
					// 	cur <= M1;
					// end
					// else begin
					// 	cur <= M0;
					// end

                    // Switch to M1 if:
                    //   - Burst ends (RLAST) and M1 waiting, OR
                    //   - M0 idle and M1 requesting
                    if ((s_RLAST && s_RVALID && m1_ARVALID) || (~m0_ARVALID && m1_ARVALID)) begin
                        cur <= M1;
                    end
                end
                M1: begin
					// if (m1_ARVALID) begin
					// 	cur <= M1;
					// end
					// else if ((s_RLAST && s_RVALID) || m0_ARVALID) begin
					// 	cur <= M0;
					// end
					// else begin
					// 	cur <= M1;
					// end

                    // Switch to M0 if:
                    //   - Burst ends (RLAST) and M0 waiting, OR  
                    //   - M1 idle and M0 requesting
                    if ((s_RLAST && s_RVALID && m0_ARVALID) || (~m1_ARVALID && m0_ARVALID)) begin
                        cur <= M0;
                    end
                end
            endcase
        end
    end

    // ================================================================
    // GRANT OUTPUT
    // ================================================================
    always @(*) begin
		m0_rgrnt = (cur == M0);
		m1_rgrnt = (cur == M1);
	end

endmodule

