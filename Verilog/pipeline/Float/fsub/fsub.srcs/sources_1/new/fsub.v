`timescale 1ns/1ps
module fsub (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);
    wire [31:0] b_neg = {~b[31], b[30:0]};

    fadd u_fadd (
        .a(a),
        .b(b_neg),
        .y(y)
    );
endmodule
