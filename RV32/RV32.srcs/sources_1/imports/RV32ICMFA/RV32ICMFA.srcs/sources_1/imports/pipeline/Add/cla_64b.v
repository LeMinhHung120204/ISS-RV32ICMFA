`timescale 1ns/1ps
module cla_64b(
    input  [63:0] a, b,
    input         cin,
    output [63:0] sum,
    output        cout
);
    wire G0, G1, G2, G3;
    wire P0, P1, P2, P3;
    wire C16, C32, C48;

    cla_16b b0 (.a(a[15:0]),     .b(b[15:0]),    .cin(cin),  .sum(sum[15:0]),    .G16(G0), .P16(P0));
    cla_16b b1 (.a(a[31:16]),    .b(b[31:16]),   .cin(C16),  .sum(sum[31:16]),   .G16(G1), .P16(P1));
    cla_16b b2 (.a(a[47:32]),    .b(b[47:32]),   .cin(C32),  .sum(sum[47:32]),   .G16(G2), .P16(P2));
    cla_16b b3 (.a(a[63:48]),    .b(b[63:48]),   .cin(C48),  .sum(sum[63:48]),   .G16(G3), .P16(P3) );

    assign C16  = G0 | (P0 & cin);
    assign C32  = G1 | (P1 & G0) | (P1 & P0 & cin);
    assign C48  = G2 | (P2 & G1) | (P2 & P1 & G0) | (P2 & P1 & P0 & cin);
    assign cout = G3 | (P3 & G2) | (P3 & P2 & G1) | (P3 & P2 & P1 & G0) | (P3 & P2 & P1 & P0 & cin);
endmodule