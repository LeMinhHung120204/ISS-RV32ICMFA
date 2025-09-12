`timescale 1ns/1ps
module cla_16b(
    input [15:0]    a, b,
    input           cin,
    // output          cout,
    output [15:0]   sum,
    output          G16,
    output          P16
);
    wire P0, P1, P2, P3, G0, G1, G2, G3;
    wire C1, C2, C3;
    
    assign C1   = G0 | (P0 & cin);
    assign C2   = G1 | (P1 & G0) | (P1 & P0 & cin);
    assign C3   = G2 | (P2 & G1) | (P2 & P1 & G0) | (P2 & P1 & P0 & cin);
    assign cout = G3 | (P3 & G2) | (P3 & P2 & G1) | (P3 & P2 & P1 & G0) | (P3 & P2 & P1 & P0 & cin);

    assign G16  = G3 | (P3 & G2) | (P3 & P2 & G1) | (P3 & P2 & P1 & G0);
    assign P16  = P3 & P2 & P1 & P0;


    cla_4b s0 (.a(a[3:0]),      .b(b[3:0]),     .cin(cin),  .sum(sum[3:0]),     .G(G0), .P(P0));
    cla_4b s1 (.a(a[7:4]),      .b(b[7:4]),     .cin(C1),   .sum(sum[7:4]),     .G(G1), .P(P1));
    cla_4b s2 (.a(a[11:8]),     .b(b[11:8]),    .cin(C2),   .sum(sum[11:8]),    .G(G2), .P(P2));
    cla_4b s3 (.a(a[15:12]),    .b(b[15:12]),   .cin(C3),   .sum(sum[15:12]),   .G(G3), .P(P3));
endmodule