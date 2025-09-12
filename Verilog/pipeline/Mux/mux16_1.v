`timescale 1ns/1ps
module mux16_1 #(
    parameter DATA_WIDTH = 32
)(
    input   [DATA_WIDTH - 1:0] in0, in1, in2, in3, in4, in5, in6, in7, in8, in9,
    input   [DATA_WIDTH - 1:0] in10, in11, in12, in13, in14, in15,
    input   [3:0]               sel,
    output reg  [DATA_WIDTH - 1:0] res
);

    always @(*) begin
        case (sel)
            4'd0:       res = in0;
            4'd1:       res = in1;
            4'd2:       res = in2;
            4'd3:       res = in3;
            4'd4:       res = in4;    
            4'd5:       res = in5;
            4'd6:       res = in6;
            4'd7:       res = in7;
            4'd8:       res = in8;
            4'd9:       res = in9;
            4'd10:      res = in10;
            4'd11:      res = in11;
            4'd12:      res = in12;
            4'd13:      res = in13;
            4'd14:      res = in14;
            4'd15:      res = in15;
            default:    res = 32'd0;
        endcase
    end 
endmodule