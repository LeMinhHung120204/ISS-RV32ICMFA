`timescale 1ns/1ps
module MulDivDecode(
    input   MulDivOp,
    input   [2:0] funct3,
    output reg  [1:0] Mul_Div_unsigned, 
    output reg  is_high
);
    /*
        Mul_Div_unsigned: 00:signed, 01:unsigned, 11:(signed x unsigned)
    */

    always @(*) begin
        case(MulDivOp) 
            1'b0: begin
                Mul_Div_unsigned    = 2'b0;
                is_high             = 1'b0;
            end 
            1'b1: begin
                case(funct3)
                    3'd0: begin
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                    end 
                    3'd1: begin
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b1;
                    end 
                    3'd2: begin
                        Mul_Div_unsigned    = 2'b11;
                        is_high             = 1'b1;
                    end 
                    3'd3: begin
                        Mul_Div_unsigned    = 2'b01;
                        is_high             = 1'b1;
                    end 
                    3'd4: begin
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                    end 
                    3'd5: begin
                        Mul_Div_unsigned    = 2'b01;
                        is_high             = 1'b0;
                    end 
                    3'd6: begin
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                    end 
                    3'd7: begin
                        Mul_Div_unsigned    = 2'b01;
                        is_high             = 1'b0;
                    end 
                    default: begin
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                    end 
                endcase
            end 
            default: begin
                Mul_Div_unsigned    = 2'b0;
                is_high             = 1'b0;
            end 
        endcase
    end 
endmodule