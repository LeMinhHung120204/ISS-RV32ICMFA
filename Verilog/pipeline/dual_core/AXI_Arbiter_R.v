`timescale 1ns/1ns

// 2-master Round-Robin arbiter for AXI Read channel
module AXI_Arbiter_R (
	input  ACLK,
	input  ARESETn,
	// Masters
	input  m0_ARVALID,
	input  m0_RREADY,
	input  m1_ARVALID,
	input  m1_RREADY,
	// Slave signals
	input  s_RVALID,
	input  s_RLAST,
	// Grants
	output reg m0_rgrnt,
	output reg m1_rgrnt
);

	parameter M0 = 1'b0;
	parameter M1 = 1'b1;
	reg cur;

	// Next-pointer logic: hold grant while master has active AR or while read data is returning
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

					if ((s_RLAST && s_RVALID && m1_ARVALID) || (!m0_ARVALID && m1_ARVALID)) begin
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

					if ((s_RLAST && s_RVALID && m0_ARVALID) || (!m1_ARVALID && m0_ARVALID)) begin
						cur <= M0;
					end
				end
			endcase
		end
	end

	always @(*) begin
		m0_rgrnt = (cur == M0);
		m1_rgrnt = (cur == M1);
	end

endmodule

