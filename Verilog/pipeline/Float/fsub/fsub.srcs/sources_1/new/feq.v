// feq.v
`timescale 1ns/1ps
module feq (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);
    wire a_nan  = (a[30:23] == 8'hFF) && (a[22:0] != 0);
    wire b_nan  = (b[30:23] == 8'hFF) && (b[22:0] != 0);
    wire a_zero = (a[30:23] == 8'h00) && (a[22:0] == 0);
    wire b_zero = (b[30:23] == 8'h00) && (b[22:0] == 0);

    always @(*) begin
        if (a_nan || b_nan)
            y = 32'b0;
        else if (a_zero && b_zero)
            y = 32'b1;
        else if (a == b)
            y = 32'b1;
        else
            y = 32'b0;
    end
endmodule
