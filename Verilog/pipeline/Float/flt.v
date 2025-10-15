`timescale 1ns / 1ps
module flt #(
    parameter WIDTH = 32
)(
    input   [WIDTH-1:0] a, b,
    output  [WIDTH-1:0] out,
    output  exception
);
    wire sa, sb;
    wire [7:0]  ea, eb;
    wire [22:0] fa, fb;

    assign sa = a[31];
    assign sb = b[31];
    assign ea = a[30:23];
    assign eb = b[30:23];
    assign fa = a[22:0];
    assign fb = b[22:0];

    wire a_is_nan   = (ea == 8'hFF) && (fa != 0);
    wire b_is_nan   = (eb == 8'hFF) && (fb != 0);
    wire a_is_snan  = a_is_nan && (fa[22] == 1'b0);     // quiet bit = 0
    wire b_is_snan  = b_is_nan && (fb[22] == 1'b0);
    wire a_is_zero  = (ea == 8'd0) && (fa == 23'd0);    //+0 và -0
    wire b_is_zero  = (eb == 8'd0) && (fb == 23'd0);

    wire invalid    = a_is_san | b_is_san;

    wire lt_ordered =
        // ±0 so với ±0 -> false
        (a_is_zero && b_is_zero) ? 1'b0 :
        // Khác dấu: a âm & b dương -> a<b
        (sa ^ sb)   ? sa :
        (!sa)       ? (a[30:0] < b[30:0]) : (a[30:0] > b[30:0]);

    wire lt             = invalid ? 1'b0 : lt_ordered;
    assign out          = {31'd0, lt};
    assign exception    = invalid;
endmodule