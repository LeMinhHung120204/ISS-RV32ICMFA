`timescale 1ns/1ps
module mux8_1 #(
    parameter WIDTH = 32
)(
    input       [WIDTH - 1:0]   in0, in1, in2, in3, in4, in5, in6, in7,
    input       [2:0]           sel,
    output reg  [WIDTH - 1:0]   res
);
    always @(*) begin
        case(sel)
            3'b000: res = in0;
            3'b001: res = in1;
            3'b010: res = in2;
            3'b011: res = in3;
            3'b100: res = in4;
            3'b101: res = in5;
            3'b110: res = in6;
            3'b111: res = in7;
            default: res = 32'd0;
        endcase
    end 
endmodule