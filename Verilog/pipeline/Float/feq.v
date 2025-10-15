`timescale 1ns / 1ps
module feq #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0]  a, b,
    output [WIDTH-1:0]  out,
    output              exception // =1 neu co input sNaN 
);
    wire        sa = a[31];
    wire        sb = b[31];
    wire [7:0]  ea = a[30:23];
    wire [7:0]  eb = b[30:23];
    wire [22:0] fa = a[22:0];
    wire [22:0] fb = b[22:0];

    wire a_is_nan   = (ea == 8'hFF) && (fa != 0);
    wire b_is_nan   = (eb == 8'hFF) && (fb != 0);
    wire a_is_snan  = a_is_nan && (fa[22] == 1'b0); // quiet bit = 0
    wire b_is_snan  = b_is_nan && (fb[22] == 1'b0);
    wire a_is_zero  = (ea == 8'd0) && (fa == 23'd0);
    wire b_is_zero  = (eb == 8'd0) && (fb == 23'd0);

    wire eq_ordered     = (a_is_zero && b_is_zero) ? 1'b1 : // +0 == -0
                        (a == b);                           // con lai

    wire eq_res         = (a_is_nan || b_is_nan) ? 1'b0 : eq_ordered;

    assign y            = {31'd0, eq_res};
    assign exception    = a_is_snan | b_is_snan;
endmodule
