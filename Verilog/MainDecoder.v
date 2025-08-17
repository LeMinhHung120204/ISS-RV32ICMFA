module MainDecoder(
    input [6:0] op,
    output reg Branch, MemWrite, ALUSrc, RegWrite, Jump
    output reg [1:0] ImmSrc, ALUOp, ResultSrc
);

    always @(*) begin
        case(op)
            2'b0000011: begin           // lw
                RegWrite    = 1'b1;
                ImmSrc      = 2'b00;
                ALUSrc      = 1'b1;
                MemWrite    = 1'b0;
                ResultSrc   = 2'b01;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
            end 
            2'b0100011: begin           // sw, ResultSrc = xx
                RegWrite    = 1'b0;
                ImmSrc      = 2'b01;
                ALUSrc      = 1'b1;
                MemWrite    = 1'b1;
                ResultSrc   = 2'b00;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
            end 
            2'b0110011: begin           // R-type, ImmSrc = xx
                RegWrite    = 1'b1;
                ImmSrc      = 2'b00;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 2'b00;
                Branch      = 1'b0;
                ALUOp       = 2'b10;
                Jump        = 1'b0;
            end 
            2'b1100011: begin           // beq, ResultSrc = xx
                RegWrite    = 1'b0;
                ImmSrc      = 2'b10;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 2'b00;
                Branch      = 1'b1;
                ALUOp       = 2'b01;
                Jump        = 1'b0;
            end 
            2'b0010011: begin           // I-type ALU, ALUSrc = x   
                RegWrite    = 1'b1;
                ImmSrc      = 2'b00;
                ALUSrc      = 1'b1;
                MemWrite    = 1'b0;
                ResultSrc   = 2'b00;
                Branch      = 1'b0;
                ALUOp       = 2'b10;
                Jump        = 1'b0;
            end 
            2'b0010011: begin           // jal, ALUSrc = x, ALUOp = xx
                RegWrite    = 1'b1;
                ImmSrc      = 2'b11;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 2'b10;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b1;
            end 
            default: begin
                RegWrite    = 1'b0;
                ImmSrc      = 2'b00;
                ALUSrc      = 1'b0;
                MemWrite    = 1'b0;
                ResultSrc   = 2'b00;
                Branch      = 1'b0;
                ALUOp       = 2'b00;
                Jump        = 1'b0;
            end 
        endcase
    end
endmodule