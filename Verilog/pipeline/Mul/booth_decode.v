`timescale 1ns/1ps
module booth_decode #(
    parameter DATA_WIDH = 32
)(
    input   [DATA_WIDH - 1:0] A,
    input   [3:0]             sel,
    output  [DATA_WIDH + 1:0] res
);
    wire [DATA_WIDH + 1:0] pp;

    wire [DATA_WIDH + 1:0] A_ex;
    assign A_ex = {{2{A_ex[31]}}, A};

    mux16_1 #(.DATA_WIDTH(34)) mux16_1_inst (
        .in0(34'd0),                    // 0X
        .in1(A_ex),                        // +X
        .in2(A_ex),                        // +X
        .in3(A_ex << 1),                   // +2X
        .in4(A_ex << 1),                   // +2X
        .in5(A_ex << 1 + A_ex),               // +3X
        .in6(A_ex << 1 + A_ex),               // +3X
        .in7(A_ex << 2),                   // +4X
        .in8(~(A_ex << 2) + 1'b1),         // -4X
        .in9(~(A_ex << 1) - A_ex + 1'b1),     // -3X
        .in10(~(A_ex << 1) - A_ex + 1'b1),    // -3X
        .in11(~(A_ex << 1) + 1'b1),        // -2X
        .in12(~(A_ex << 1) + 1'b1),        // -2X
        .in13(~(A_ex) + 1'b1),             // -X
        .in14(~(A_ex) + 1'b1),             // -X
        .in15(34'd0),                   // 0X
        .sel(sel),
        .res(pp)
    );

    assign res = pp;
endmodule