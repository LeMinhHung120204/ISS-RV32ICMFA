`timescale 1ns/1ps
module MainDecoder(
    input       [6:0] op, funct7,
    input       [2:0] funct3,
    output reg  Branch, MemWrite, ALUSrc, RegWrite, Jump, PCTargetSrc,
    output reg  [1:0] ALUOp,
    output reg  [2:0] ImmSrc, ResultSrc, StoreSrc
);

    always @(*) begin
        case(op)
            2'b0000011: begin
                case(funct3)
                    3'd0: begin
                        StoreSrc = 3'b001;  // lb
                    end
                    3'd1: begin
                        StoreSrc = 3'b010;  // lh
                    end
                    3'd2: begin
                        StoreSrc = 3'b000;  // lw
                    end
                    3'd4: begin
                        StoreSrc = 3'b101;  // lbu
                    end
                    3'd5: begin
                        StoreSrc = 3'b110;  // lhu
                    end
                    default: begin
                        StoreSrc = 3'b000;
                    end 
                endcase 
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
            7'b0100011: begin          
                case(funct3)
                    3'd0: begin
                        StoreSrc = 3'b001;  // sb
                    end
                    3'd1: begin
                        StoreSrc = 3'b010;  // sh
                    end
                    3'd2: begin
                        StoreSrc = 3'b000;  // sw
                    end
                    default: begin
                        StoreSrc = 3'b000;
                    end 
                endcase 
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
            7'b0110011: begin           // R-type, M-extension, ImmSrc = xx, PCTargetSrc = x
                case(funct7[0])
                    1'b0: begin                 // R-type
                        ResultSrc   = 3'b000;
                    end 
                    1'b1: begin
                        case(funct3)
                            3'd0, 3'd1, 3'd2, 3'd3: ResultSrc   = 3'b101;   // Mul
                            3'd4, 3'd5:             ResultSrc   = 3'b110;   // Div
                            3'd6, 3'd7:             ResultSrc   = 3'b111;   // Remainder
                            default: ResultSrc   = 3'b000;
                        endcase
                    end 
                    default: begin
                        ResultSrc   = 3'b000;
                    end 
                endcase
                RegWrite    = 1'b1;
                ImmSrc      = 3'b000;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                
                Branch      = 1'b0;
                ALUOp       = 2'b10;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
                StoreSrc    = 3'b000;
            end 
            7'b1100011: begin           // branch, ResultSrc = xxx
                RegWrite    = 1'b0;
                ImmSrc      = 3'b010;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b000;
                Branch      = 1'b1;
                ALUOp       = 2'b01;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
                StoreSrc    = 3'b000;
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
                StoreSrc    = 3'b000;
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
                StoreSrc    = 3'b000;
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
                StoreSrc    = 3'b000;
            end 
            7'b0110111: begin           // LoadUpperImm lui ALUOp = xx, ALUSrc = x, PCTargetSrc= x 
                RegWrite    = 1'b1;
                ImmSrc      = 3'd4;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 3'b011;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
                PCTargetSrc = 1'b0;
                StoreSrc    = 3'b000;
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
                StoreSrc    = 3'b000;
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
                StoreSrc    = 3'b000;
            end 
        endcase
    end
endmodule