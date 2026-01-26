`timescale 1ns/1ns

// 2-master Round-Robin arbiter for AXI Write channel
module AXI_Arbiter_W (
    input  ACLK,
    input  ARESETn,
    // Masters
    input  m0_AWVALID,
    input  m0_WVALID,
    input  m0_BREADY,
    input  m1_AWVALID,
    input  m1_WVALID,
    input  m1_BREADY,
    // Slave signals
    input  s_BVALID,
    // Grants
    output reg m0_wgrnt,
    output reg m1_wgrnt
);

    parameter M0 = 1'b0;
    parameter M1 = 1'b1;
    reg cur;

    // Hold grant until write response completes (simple approach)
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            cur <= M0;
        end 
        else begin
            case (cur)
                M0: begin
                    // if (m0_AWVALID || m0_WVALID) begin
                    //     cur <= M0;
                    // end
                    // else if (s_BVALID || m1_AWVALID || m1_WVALID) begin
                    //     cur <= M1;
                    // end
                    // else begin
                    //     cur <= M0;
                    // end

                    if ((s_BVALID && m1_AWVALID) || (!(m0_AWVALID || m0_WVALID) && (m1_AWVALID || m1_WVALID))) begin
                        cur <= M1;
                    end
                end
                M1: begin
                    // if (m1_AWVALID || m1_WVALID) begin
                    //     cur <= M1;
                    // end
                    // else if (s_BVALID || m0_AWVALID || m0_WVALID) begin
                    //     cur <= M0;
                    // end
                    // else begin
                    //     cur <= M1;
                    // end

                    if ((s_BVALID && m0_AWVALID) || (!(m1_AWVALID || m1_WVALID) && (m0_AWVALID || m0_WVALID))) begin
                        cur <= M0;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        m0_wgrnt = (cur == M0);
        m1_wgrnt = (cur == M1);
    end

endmodule
