`timescale 1ns/1ps

module AluDecoder(
    input       [1:0]   ALUOp,
    input       [2:0]   funct3,
    input               funct7_5, op_5,
    output reg  [3:0]   ALUControl
);
    always @(*) begin
        case(ALUOp)
            2'b00: begin
                ALUControl = 4'b0000;    // (add) intruction lw, sw
            end 
            2'b01: begin
                ALUControl = 4'b1000;    // (sub) intruction beq 
            end 
            2'b10: begin
                case(funct3)
                    3'b00: begin
                        case({op_5, funct7_5})
                            2'b00, 2'b01, 2'b10:    ALUControl = 4'b0000;    // (add) intruction add
                            2'b11:                  ALUControl = 4'b1000;    // (sub) intruction sub
                            default:                ALUControl = 4'b0000;
                        endcase
                    end 
                    3'b010: begin
                        ALUControl = 4'b1001;    // (set less than) slt
                    end 
                    3'b110: begin
                        ALUControl = 4'b0101;    // or 
                    end 
                    3'b111: begin
                        ALUControl = 4'b0100;    // and 
                    end 
                    default: begin
                        ALUControl = 4'b0000;
                    end 
                endcase
            end
            default: begin
                ALUControl = 4'b000;
            end
        endcase
    end 
endmodule