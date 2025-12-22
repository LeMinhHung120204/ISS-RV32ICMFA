`timescale 1ns/1ps
module MainDecoder(
    input       [6:0] op, funct7,
    input       [2:0] funct3,
    output reg  Branch, 
    output reg  MemWrite, 
    output reg  ALUSrc, 
    output reg  RegWrite, 
    output reg  Jump, 
    output reg  addr_addend_sel,
    output reg  FRegWrite, 
    output reg  ResPCSel, 
    output reg  MDUOp,
    output reg  [1:0]   ALUOp, 
    output reg  [1:0]   ResExSel,
    output reg  [2:0]   ImmSrc, 
    output reg  [2:0]   ResultSrc, 
    output reg  [2:0]   StoreSrc, 
    output reg  [2:0]   FPUOp,
    output reg  data_req
    // output reg  AtomicOp  // ATOMIC: Atomic operation flag
);

    always @(*) begin
        case(op)
            7'b0000011: begin
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
                data_req        = 1'b1;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;

                RegWrite        = 1'b1;
                ImmSrc          = 3'b000;
                ALUSrc          = 1'b1;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b001;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
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
                data_req        = 1'b1;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;

                RegWrite        = 1'b0;
                ImmSrc          = 3'b001;
                ALUSrc          = 1'b1;
                MemWrite        = 1'b1;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                MDUOp           = 1'b0;
                AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b0110011: begin           // R-type, M-extension
                case(funct7[0])
                    1'b0: begin            // R-type
                        ResExSel    = 2'b00;
                        MDUOp       = 1'b0;
                    end 
                    1'b1: begin            // M-extension       
                        ResExSel    = 2'b01;
                        MDUOp       = 1'b1;
                    end 
                    default: begin
                        MDUOp       = 1'b0;
                        ResExSel    = 2'b00;
                    end 
                endcase
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;

                ResultSrc       = 3'b000;
                RegWrite        = 1'b1;
                ImmSrc          = 3'b000;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                
                Branch          = 1'b0;
                ALUOp           = 2'b10;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1100011: begin           // branch
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;

                RegWrite        = 1'b0;
                ImmSrc          = 3'b010;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b1;
                ALUOp           = 2'b01;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b0010011: begin           // I-type ALU
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;

                RegWrite        = 1'b1;
                ImmSrc          = 3'b000;
                ALUSrc          = 1'b1;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b10;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1101111: begin           // jal
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b1;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;
                
                RegWrite        = 1'b1;
                ImmSrc          = 3'b011;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b010;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b1;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1100111: begin           // jalr
                data_req        = 1'b0;
                addr_addend_sel = 1'b1;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b1;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;
                
                RegWrite        = 1'b1;
                ImmSrc          = 3'b000;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b010;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b1;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b0110111: begin           // lui
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;
                
                RegWrite        = 1'b1;
                ImmSrc          = 3'd4;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b011;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b0010111: begin           // auipc
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;
                
                RegWrite        = 1'b1;
                ImmSrc          = 3'd4;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b010;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end
            7'b0000111: begin           // flw
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b1;
                FPUOp           = 3'd0;

                RegWrite        = 1'b0;
                ImmSrc          = 3'd0;
                ALUSrc          = 1'b1;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b001;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b0100111: begin           // fsw
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd6;

                RegWrite        = 1'b0;
                ImmSrc          = 3'd1;
                ALUSrc          = 1'b1;
                MemWrite        = 1'b1;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1000011: begin           // fmadd
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b10;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b1;
                FPUOp           = 3'd1;

                RegWrite        = 1'b0;
                ImmSrc          = 3'd0;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1000111: begin           // fmsub
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b10;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b1;
                FPUOp           = 3'd2;

                RegWrite        = 1'b0;
                ImmSrc          = 3'd0;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1001111: begin           // fnmadd
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b10;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b1;
                FPUOp           = 3'd3;

                RegWrite        = 1'b0;
                ImmSrc          = 3'd0;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1001011: begin           // fnmsub
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b10;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b1;
                FPUOp           = 3'd4;

                RegWrite        = 1'b0;
                ImmSrc          = 3'd0;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            7'b1010011: begin           // FPU instructions
                case(funct7)
                    7'b110_0000: begin      // fdiv.s, fsgnjn.s, fsgnjx.s
                        RegWrite = 1'b1;
                    end 
                    7'b111_0000: begin      // fsqrt.s
                        RegWrite = 1'b1;
                    end 
                    default: begin
                        RegWrite = 1'b0;
                    end
                endcase
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b10;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b1;
                FPUOp           = 3'd5;

                ImmSrc          = 3'd0;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
            // 7'b0101111: begin // ATOMIC: Atomic instructions (LR/SC/AMO)
            //     AtomicOp        = 1'b1;  // ATOMIC: Enable atomic operation
            //     addr_addend_sel = 1'b0;
            //     ResExSel        = 2'b00;
            //     ResPCSel        = 1'b0;
            //     FRegWrite       = 1'b0;
            //     FPUOp           = 3'd0;
            //     RegWrite        = 1'b1;
            //     ImmSrc          = 3'b000;
            //     ALUSrc          = 1'b0;
            //     MemWrite        = 1'b0;
            //     ResultSrc       = 3'b000;
            //     Branch          = 1'b0;
            //     ALUOp           = 2'b00;
            //     Jump            = 1'b0;
            //     StoreSrc        = 3'b000;
            //     MDUOp           = 1'b0;
            // end
            default: begin
                data_req        = 1'b0;
                addr_addend_sel = 1'b0;
                ResExSel        = 2'b00;
                ResPCSel        = 1'b0;
                FRegWrite       = 1'b0;
                FPUOp           = 3'd0;

                RegWrite        = 1'b0;
                ImmSrc          = 3'd0;
                ALUSrc          = 1'b0;
                MemWrite        = 1'b0;
                ResultSrc       = 3'b000;
                Branch          = 1'b0;
                ALUOp           = 2'b00;
                Jump            = 1'b0;
                StoreSrc        = 3'b000;
                MDUOp           = 1'b0;
                // AtomicOp        = 1'b0;  // ATOMIC
            end 
        endcase
    end
endmodule
