`timescale 1ns/1ps
module Div_unit #(
    parameter DATA_WIDTH = 32
)(
    input   [DATA_WIDTH:0]      A, M,
    input   [DATA_WIDTH - 1:0]  Q,
    output  [DATA_WIDTH:0]      A_new,
    output  [DATA_WIDTH - 1:0]  Q_new
);
    wire [DATA_WIDTH:0]     A_tmp;
    wire [DATA_WIDTH - 1:0] Q_tmp;

    assign {A_tmp, Q_tmp}   = {A[DATA_WIDTH-1:0], Q, 1'b0};
    assign A_new            = (A_tmp[DATA_WIDTH] ? A_tmp + M : A_tmp - M);
    assign Q_new            = {Q_tmp[DATA_WIDTH-1:1], (~A_new[DATA_WIDTH])};
endmodule

module DivStage2 #(parameter W=32)(
  input  [W:0]     A_in,
  input  [W:0]     M_in,
  input  [W-1:0]   Q_in,
  output [W:0]     A_out,
  output [W-1:0]   Q_out
);
  wire [W:0]    A1;
  wire [W-1:0]  Q1;
  Div_unit s0(.A(A_in), .M(M_in), .Q(Q_in), .A_new(A1),     .Q_new(Q1));
  Div_unit s1(.A(A1),   .M(M_in), .Q(Q1),   .A_new(A_out),  .Q_new(Q_out));
endmodule