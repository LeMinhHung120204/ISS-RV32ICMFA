`timescale 1ns/1ps
module fle (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y   // bit 0 = 1 nếu a <= b, ngược lại = 0
);
    wire a_nan  = (a[30:23] == 8'hFF) && (a[22:0] != 0);
    wire b_nan  = (b[30:23] == 8'hFF) && (b[22:0] != 0);
    wire a_zero = (a[30:23] == 8'h00) && (a[22:0] == 0);
    wire b_zero = (b[30:23] == 8'h00) && (b[22:0] == 0);

    // So sánh IEEE754 cơ bản
    function automatic bit float_le(input [31:0] x, input [31:0] y);
        if (x[31] != y[31]) begin
            float_le = x[31]; // nếu x âm và y dương => x < y
        end else if (x[30:0] == y[30:0]) begin
            float_le = 1;     // bằng nhau
        end else if (x[31] == 0) begin
            float_le = (x[30:0] < y[30:0]); // cả hai dương
        end else begin
            float_le = (x[30:0] > y[30:0]); // cả hai âm
        end
    endfunction

    always @(*) begin
        if (a_nan || b_nan)
            y = 32'b0;
        else if (a_zero && b_zero)
            y = 32'b1;
        else if (float_le(a, b))
            y = 32'b1;
        else
            y = 32'b0;
    end
endmodule
