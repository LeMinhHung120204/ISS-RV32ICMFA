`timescale 1ns/1ps
module fsgnj #(
    parameter WIDTH = 32
)(
    input   [WIDTH-1:0] rs1, rs2,
    output  [WIDTH-1:0] rd
);
    assign rd = {rs2[31], rs1[30:0]};
endmodule 

module fsgnjn #(
    parameter WIDTH = 32
)(
    input   [WIDTH-1:0] rs1, rs2,
    output  [WIDTH-1:0] rd
);
    assign rd = {~rs2[31], rs1[30:0]};
endmodule 

module fsgnjx #(
    parameter WIDTH = 32
)(
    input   [WIDTH-1:0] rs1, rs2,
    output  [WIDTH-1:0] rd
);
    assign rd = {rs1[31] ^ rs2[31], rs1[30:0]};
endmodule 