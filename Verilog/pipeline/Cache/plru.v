`timescale 1ns/1ps
module plru(
    input   prev_bit, left_hit, right_hit
,   output reg plru_bit
);
    always @(*) begin
        case({left_hit, right_hit})
            2'b10: begin    // hit trai -> set 1
                plru_bit = 1'b1;
            end 
            2'b01: begin    // hit phai -> set 0
                plru_bit = 1'b0;
            end 
            default: begin
                plru_bit = prev_bit;
            end 
        endcase
    end 
endmodule