`timescale 1ns/1ps
// from Lee Min Hunz with luv
module MulDivDecode(
    input   MulDivOp
,   input   [2:0] funct3
,   output reg  [1:0] Mul_Div_unsigned, MulDivControl
,   output reg  is_high, valid_MDU
);
    /*
        Mul_Div_unsigned: 00:signed, 01:unsigned, 11:(signed x unsigned)
    */

    always @(*) begin
        case(MulDivOp) 
            1'b0: begin
                Mul_Div_unsigned    = 2'b0;
                MulDivControl       = 2'b0;
                is_high             = 1'b0;
                valid_MDU           = 1'b0;
            end 
            1'b1: begin
                case(funct3)
                    3'd0: begin     // mul
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                        MulDivControl       = 2'b00;
                        valid_MDU           = 1'b1;
                    end 
                    3'd1: begin     // mulh
                        Mul_Div_unsigned    = 2'b01;
                        is_high             = 1'b1;
                        MulDivControl       = 2'b00;
                        valid_MDU           = 1'b1;
                    end             // mulhsu
                    3'd2: begin
                        Mul_Div_unsigned    = 2'b11;
                        is_high             = 1'b1;
                        MulDivControl       = 2'b00;
                        valid_MDU           = 1'b1;
                    end 
                    3'd3: begin     // mulhu
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b1;
                        MulDivControl       = 2'b00;
                        valid_MDU           = 1'b1;
                    end 
                    3'd4: begin     // div
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                        MulDivControl       = 2'b01;
                        valid_MDU           = 1'b1;
                    end 
                    3'd5: begin     // divu
                        Mul_Div_unsigned    = 2'b01;
                        is_high             = 1'b0;
                        MulDivControl       = 2'b01;
                        valid_MDU           = 1'b1;
                    end             // rem
                    3'd6: begin
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                        MulDivControl       = 2'b10;
                        valid_MDU           = 1'b1;
                    end 
                    3'd7: begin     // remu
                        Mul_Div_unsigned    = 2'b01;
                        is_high             = 1'b0;
                        MulDivControl       = 2'b10;
                        valid_MDU           = 1'b1;
                    end 
                    default: begin
                        Mul_Div_unsigned    = 2'b00;
                        is_high             = 1'b0;
                    end 
                endcase
            end 
            default: begin
                Mul_Div_unsigned    = 2'b0;
                MulDivControl       = 2'b0;
                is_high             = 1'b0;
                valid_MDU           = 1'b0;
            end 
        endcase
    end 
endmodule