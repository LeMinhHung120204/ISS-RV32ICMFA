`timescale 1ns/1ps
module cla_4b (
    input  [3:0] a, b,
    input        cin,
    output [3:0] sum,
    output       G,   // group generate
    output       P    // group propagate
);

    wire [3:0] g, p, c;

    // Generate & Propagate từng bit
    assign g = a & b;   // generate: a*b
    assign p = a ^ b;   // propagate: a xor b

    // Carry lookahead
    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & c[1]);
    assign c[3] = g[2] | (p[2] & c[2]);

    // Sum
    assign sum = p ^ c;

    // Group Generate/Propagate (cho ghép nhiều CLA)
    assign G = g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) | (p[3]&p[2]&p[1]&g[0]);
    assign P = p[3] & p[2] & p[1] & p[0];

endmodule
