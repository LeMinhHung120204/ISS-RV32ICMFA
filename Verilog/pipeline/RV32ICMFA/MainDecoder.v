`timescale 1ns/1ps
module MainDecoder(
    input       [6:0] op,
    output reg  Branch, MemWrite, ALUSrc, RegWrite, Jump, PCTargetSrc,
    output reg  [1:0] ALUOp,
    output reg  [2:0] ImmSrc, ResultSrc
);

    always @(*) begin
        case(op)
            2'b0000011: begin           // lw PCTargetSrc = x
                RegWrite    = 1'b1;
                ImmSrc      = 3'b000;
                ALUSrc      = 1'b1;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b001;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end 
            7'b0100011: begin           // sw, ResultSrc = xx, PCTargetSrc = x
                RegWrite    = 1'b0;
                ImmSrc      = 3'b001;
                ALUSrc      = 1'b1;
                MemWrite    = 1'b1;
                ResultSrc   = 3'b000;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end 
            7'b0110011: begin           // R-type, ImmSrc = xx, PCTargetSrc = x
                RegWrite    = 1'b1;
                ImmSrc      = 3'b000;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b000;
                Branch      = 1'b0;
                ALUOp       = 2'b10;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end 
            7'b1100011: begin           // branch, ResultSrc = xx
                RegWrite    = 1'b0;
                ImmSrc      = 3'b010;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b000;
                Branch      = 1'b1;
                ALUOp       = 2'b01;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end 
            7'b0010011: begin           // I-type ALU, ALUSrc = x, PCTargetSrc = x  
                RegWrite    = 1'b1;
                ImmSrc      = 3'b000;
                ALUSrc      = 1'b1;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b000;
                Branch      = 1'b0;
                ALUOp       = 2'b10;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end 
            7'b1101111: begin           // jal, ALUSrc = x, ALUOp = xx
                RegWrite    = 1'b1;
                ImmSrc      = 3'b011;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b010;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b1;
                PCTargetSrc = 1'b0;
            end 
            7'b1100111: begin           //  JumpAndLinkReg jalr
                RegWrite    = 1'b1;
                ImmSrc      = 3'b000;
                ALUSrc      = 1'b1;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b010;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b1;
                PCTargetSrc = 1'b1;
            end 
            7'b0110111: begin           // LoadUpperImm lui ALUOp = xx, ALUSrc = xx, PCTargetSrc= x 
                RegWrite    = 1'b1;
                ImmSrc      = 3'd4;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b011;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end 
            7'b0010111: begin           // AddUpperImmtoPC auipc ALUOp = xx, ALUSrc = xx, PCTargetSrc= x 
                RegWrite    = 1'b1;
                ImmSrc      = 3'd4;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b100;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end
            default: begin
                RegWrite    = 1'b0;
                ImmSrc      = 3'b000;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b000;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
            end 
        endcase
    end
endmodule