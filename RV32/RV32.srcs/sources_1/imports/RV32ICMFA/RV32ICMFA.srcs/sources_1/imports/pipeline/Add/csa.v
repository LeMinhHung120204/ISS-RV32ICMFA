`timescale 1ns/1ps
module csa #(
    parameter WIDTH = 32
)(
	input  [WIDTH - 1:0] x, y, z,
	output [WIDTH - 1:0] sum, carry
);
	wire [WIDTH - 1:0] carry_stage;

	genvar i;
	generate
		// Stage 1: CSA – 3-input fulladders
		for (i = 0; i < WIDTH; i = i + 1) begin : CSA_STAGE
			fulladder fa (
				.a(x[i]),
				.b(y[i]),
				.cin(z[i]),
				.sum(sum[i]),
				.carry(carry_stage[i])
			);
		end
	endgenerate

	// Stage 2: Ripple Carry Adder – sum_stage1 + (carry_stage << 1)
	// assign {carry, sum}  = sum_out + (carry_stage << 1);
    assign carry = {carry_stage[WIDTH - 2:0], 1'b0};
endmodule

module fulladder (
	input a, b, cin,
	output sum, carry
);
	assign {carry, sum} = a + b + cin;
endmodule