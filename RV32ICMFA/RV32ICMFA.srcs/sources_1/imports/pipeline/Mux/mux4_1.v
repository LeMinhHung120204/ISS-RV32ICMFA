`timescale 1ns/1ps
module mux4_1 #(
    parameter WIDTH = 32
)(
    input       [WIDTH - 1:0] in0, in1, in2, in3,
    input       [1:0] sel,
    output reg  [WIDTH - 1:0] res
);
    always @(*) begin
        case(sel)
            2'b00: res = in0;
            2'b01: res = in1;
            2'b10: res = in2;
            2'b11: res = in3;
            default: res = 32'd0;
        endcase
    end 
endmodule