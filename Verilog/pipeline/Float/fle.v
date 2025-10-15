`timescale 1ns / 1ps
module fle #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0]  a, b,
    output [WIDTH-1:0]  out,
    output              exception
);
    // Unpack
    wire sa = a[31];
    wire sb = b[31];
    wire [7:0]  ea = a[30:23];
    wire [7:0]  eb = b[30:23];
    wire [22:0] fa = a[22:0];
    wire [22:0] fb = b[22:0];

    wire a_is_nan  = (ea == 8'hFF) && (fa != 23'd0);
    wire b_is_nan  = (eb == 8'hFF) && (fb != 23'd0);
    wire a_is_snan = a_is_nan && (fa[22] == 1'b0);
    wire b_is_snan = b_is_nan && (fb[22] == 1'b0);

    wire a_is_zero = (ea == 8'd0) && (fa == 23'd0);
    wire b_is_zero = (eb == 8'd0) && (fb == 23'd0);

    wire has_snan  = a_is_snan | b_is_snan;
    wire unordered = a_is_nan  | b_is_nan; 

    wire [30:0] amag = a[30:0];
    wire [30:0] bmag = b[30:0];

    wire lt_ordered =   (a_is_zero && b_is_zero)    ? 1'b0 :
                        (sa ^ sb)                   ? sa :
                        (!sa)                       ? (amag < bmag) : (amag > bmag);

    wire eq_ordered = (a_is_zero && b_is_zero) || (a[30:0] == b[30:0]);

    // a <= b: nếu unordered (NaN) -> 0.
    wire le = unordered ? 1'b0 : (lt_ordered | eq_ordered);

    assign out       = {{WIDTH-1{1'b0}}, le};
    assign exception = has_snan;
endmodule
