`timescale 1ns/1ns
// ============================================================================
// AXI Write Channel Arbiter (2-Master Round-Robin)
// ============================================================================
//
// Arbitrates write channel access between 2 masters using round-robin policy.
// Grant is held until write response received (BVALID asserted).
//
// Arbitration Policy:
//   - If both masters request: alternate based on last grant
//   - If only one requests: grant immediately
//   - Switch grant on BVALID (write complete) or when current master idle
//
// State Encoding:
//   cur = M0: Master 0 has grant
//   cur = M1: Master 1 has grant
//
// ============================================================================
module AXI_Arbiter_W (
    input  ACLK
,   input  ARESETn
    // Master request signals
,   input  m0_AWVALID       // Master 0 has address
,   input  m0_WVALID        // Master 0 has write data
,   input  m0_BREADY        // Master 0 ready for response
,   input  m1_AWVALID       // Master 1 has address
,   input  m1_WVALID        // Master 1 has write data
,   input  m1_BREADY        // Master 1 ready for response
    // Slave response signals
,   input  s_BVALID         // Slave has valid response
    // Grant outputs
,   output reg m0_wgrnt     // Master 0 granted
,   output reg m1_wgrnt     // Master 1 granted
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
    //   1. Write response received (BVALID) AND other master waiting, OR
    //   2. Current master idle AND other master requesting
    // ================================================================
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            cur <= M0;
        end 
        else begin
            case (cur)
                M0: begin
                    // Switch to M1 if:
                    //   - Write response arrived and M1 waiting, OR
                    //   - M0 idle (no AW/W) and M1 requesting
                    if ((s_BVALID && m1_AWVALID) || (~(m0_AWVALID || m0_WVALID) && (m1_AWVALID || m1_WVALID))) begin
                        cur <= M1;
                    end
                end
                M1: begin
                    // Switch to M0 if:
                    //   - Write response arrived and M0 waiting, OR
                    //   - M1 idle (no AW/W) and M0 requesting
                    if ((s_BVALID && m0_AWVALID) || (~(m1_AWVALID || m1_WVALID) && (m0_AWVALID || m0_WVALID))) begin
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
        m0_wgrnt = (cur == M0);
        m1_wgrnt = (cur == M1);
    end

endmodule
