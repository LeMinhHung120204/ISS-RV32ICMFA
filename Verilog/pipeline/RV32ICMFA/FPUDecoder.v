`timescale 1ns / 1ps
module FPUDecoder #(
    parameter WIDTH = 32
)(
    input [6:0] funct7
,   input [4:0] funct5
,   input [2:0] FPUOp, funct3
,   output reg [4:0] FPUControl
,   output reg Valid_FPU, RegSrc1, RegSrc2
);
    always @(*) begin
        case(FPUOp) // I-type / S-type
            3'd0: begin
                FPUControl  = 5'd0;
                Valid_FPU   = 1'b0;
                RegSrc1     = 1'b0;
                RegSrc2     = 1'b0;
            end 
            3'd1: begin     // fmadd
                FPUControl  = 5'b0_1011;
                Valid_FPU   = 1'b1;
                RegSrc1     = 1'b1;
                RegSrc2     = 1'b1;
            end 
            3'd2: begin     // fmsub
                FPUControl  = 5'b0_1100;
                Valid_FPU   = 1'b1;
                RegSrc1     = 1'b1;
                RegSrc2     = 1'b1;
            end 
            3'd3: begin     // fnmadd
                FPUControl  = 5'b0_1101;
                Valid_FPU   = 1'b1;
                RegSrc1     = 1'b1;
                RegSrc2     = 1'b1;
            end 
            3'd4: begin     // fnmsub
                FPUControl  = 5'b0_1110;
                Valid_FPU   = 1'b1;
                RegSrc1     = 1'b1;
                RegSrc2     = 1'b1;
            end 
            3'd5: begin     // R-type
                case(funct7)
                    7'b000_0000: begin  // fadd
                        FPUControl  = 5'b0_0000;
                        Valid_FPU   = 1'b1;
                        RegSrc1     = 1'b1;
                        RegSrc2     = 1'b1;
                    end 
                    7'b000_0100: begin  // fsub
                        FPUControl  = 5'b0_0001;
                        Valid_FPU   = 1'b1;
                        RegSrc1     = 1'b1;
                        RegSrc2     = 1'b1;
                    end 
                    7'b000_1000: begin  // fmul
                        FPUControl  = 5'b1_0001;
                        Valid_FPU   = 1'b1;
                        RegSrc1     = 1'b1;
                        RegSrc2     = 1'b1;
                    end 
                    7'b000_1100: begin  // fdiv
                        FPUControl  = 5'b0_0111;
                        Valid_FPU   = 1'b1;
                        RegSrc1     = 1'b1;
                        RegSrc2     = 1'b1;
                    end 
                    7'b010_1100: begin  // fsqrt
                        FPUControl  = 5'b1_0101;
                        Valid_FPU   = 1'b1;
                        RegSrc1     = 1'b1;
                        RegSrc2     = 1'b1;
                    end 
                    7'b001_0000: begin
                        case(funct3)
                            3'b000: begin   // fsgnj
                                FPUControl  = 5'b1_0010;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b1;
                            end 
                            3'b001: begin   // fsgnjn
                                FPUControl  = 5'b1_0011;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b1;
                            end 
                            3'b010: begin   // fsgnjx
                                FPUControl  = 5'b1_0100;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b1;
                            end 
                            default: begin
                                FPUControl  = 5'b0_0000;
                                Valid_FPU   = 1'b0;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                        endcase
                    end 
                    7'b001_0100: begin
                        case(funct3)
                            3'b000: begin    // fmin
                                FPUControl  = 5'b1_0000;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b1;
                            end 
                            3'b001: begin   // fmax
                                FPUControl  = 5'b0_1111;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b1;
                            end 
                            default: begin
                                FPUControl  = 5'b0_0000;
                                Valid_FPU   = 1'b0;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                        endcase
                    end 
                    7'b110_0000: begin
                        case(funct5[0])
                            1'b0: begin     // fcvt.w.s
                                FPUControl  = 5'b0_0101;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b0;
                            end 
                            1'b1: begin     // fcvt.wu.s
                                FPUControl  = 5'b0_0101;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b0;
                            end 
                            default: begin
                                FPUControl  = 5'b0_0000;
                                Valid_FPU   = 1'b0;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                        endcase
                    end 
                    7'b111_0000: begin      
                        case(funct3)
                            3'b000: begin   // fmv.x.w
                                FPUControl  = 5'b1_0110;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b0;
                            end 
                            3'b001: begin   // fclass
                                FPUControl  = 5'b0_0010;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b1;
                                RegSrc2     = 1'b0;
                            end 
                            default: begin
                                FPUControl  = 5'b0_0000;
                                Valid_FPU   = 1'b0;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                        endcase
                    end 
                    7'b101_0000: begin
                        case(funct3)
                                3'b000: begin   // feq
                                    FPUControl  = 5'b0_1000;
                                    Valid_FPU   = 1'b1;
                                    RegSrc1     = 1'b1;
                                    RegSrc2     = 1'b1;
                                end 
                                3'b001: begin   // flt
                                    FPUControl  = 5'b0_1010;
                                    Valid_FPU   = 1'b1;
                                    RegSrc1     = 1'b1;
                                    RegSrc2     = 1'b1;
                                end 
                                3'b010: begin   // feq
                                    FPUControl  = 5'b0_1000;
                                    Valid_FPU   = 1'b1;
                                    RegSrc1     = 1'b1;
                                    RegSrc2     = 1'b1;
                                end 
                            default: begin
                                FPUControl  = 5'b0_0000;
                                Valid_FPU   = 1'b0;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                        endcase
                    end 
                    7'b110_1000: begin
                        case(funct5[0])
                            1'b0: begin     // fcvt.s.w
                                FPUControl  = 5'b0_0011;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                            1'b1: begin     // fcvt.s.wu
                                FPUControl  = 5'b0_0100;
                                Valid_FPU   = 1'b1;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                            default: begin
                                FPUControl  = 5'b0_0000;
                                Valid_FPU   = 1'b0;
                                RegSrc1     = 1'b0;
                                RegSrc2     = 1'b0;
                            end 
                        endcase
                    end 
                    7'b111_1000: begin      // fmv.w.x
                        FPUControl  = 5'b1_0110;
                        Valid_FPU   = 1'b1;
                        RegSrc1     = 1'b0;
                        RegSrc2     = 1'b0;
                    end 
                    default: begin
                        FPUControl  = 5'd0;
                        Valid_FPU   = 1'b0;
                        RegSrc1     = 1'b0;
                        RegSrc2     = 1'b0;
                    end
                endcase
            end 
            3'd6: begin     // fsw
                FPUControl  = 5'd0;
                Valid_FPU   = 1'b0;
                RegSrc1     = 1'b0;
                RegSrc2     = 1'b1;
            end 
            default: begin
                FPUControl  = 5'd0;
                Valid_FPU   = 1'b0;
                RegSrc1     = 1'b0;
                RegSrc2     = 1'b0;
            end 
        endcase
    end 
endmodule