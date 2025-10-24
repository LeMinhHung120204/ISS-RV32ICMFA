`timescale 1ns/1ps
module cla_8b(
    input  [7:0]  a, b,
    input         cin,
    output [7:0]  sum,
    output        cout  // carry-out cua 8-bit
);
    wire P0, P1, G0, G1;
    wire C1;

    // Carry giua 2 khoi 4-bit
    assign C1   = G0 | (P0 & cin);
    assign cout = G1 | (P1 & G0) | (P1 & P0 & cin);

    cla_4b s0 (.a(a[3:0]), .b(b[3:0]), .cin(cin), .sum(sum[3:0]), .G(G0), .P(P0));
    cla_4b s1 (.a(a[7:4]), .b(b[7:4]), .cin(C1),  .sum(sum[7:4]), .G(G1), .P(P1));
endmodule
