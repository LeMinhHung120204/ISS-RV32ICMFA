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

module DivStageK #(
  parameter W = 32,
  parameter K = 3
)(
  input  [W:0]    A_in,
  input  [W:0]    M_in,
  input  [W-1:0]  Q_in,
  output [W:0]    A_out,
  output [W-1:0]  Q_out
);
  wire [W:0]    A_bus [0:K];
  wire [W-1:0]  Q_bus [0:K];

  assign A_bus[0] = A_in;
  assign Q_bus[0] = Q_in;

  genvar i;
  generate
    for (i = 0; i < K; i = i + 1) begin : G
      Div_unit u_div_unit (
        .A     (A_bus[i]),
        .M     (M_in),
        .Q     (Q_bus[i]),
        .A_new (A_bus[i+1]),
        .Q_new (Q_bus[i+1])
      );
    end
  endgenerate

  assign A_out = A_bus[K];
  assign Q_out = Q_bus[K];

endmodule