`timescale 1ns/1ps
module ALU #(
    parameter DATA_WIDTH = 32
)(
    input       [3:0]               ALUControl, 
    input       [DATA_WIDTH - 1:0]  in1, in2, 
    output reg  [DATA_WIDTH - 1:0]  result,
    output reg                      zero,
    output                          signed_less
);
    // wire [31:0] in2_mod = (ALUControl[3]) ? ~in2 : in2; 
    // wire [31:0] add_out = ()in1 + in2_mod + ALUControl[3];
    wire [DATA_WIDTH - 1:0] sub = in1 - in2;

    assign signed_less = (in1[31] == in2[31]) ? sub[31] : 
                        (ALUControl[1] ? in2[31] : in1[31]);  // ALUOp[1] = 1-SLTU | 0-SLT

    wire [4:0] shamt = in2[4:0];

    always @(*) begin
        case(ALUControl)
            4'b0000: result = in1 + in2; // add
            4'b0001: result = in1 << shamt; // sll
            4'b0010: result = in1 >> shamt; // srl
            4'b0011: result = in1 >>> shamt; // sra
            4'b0100: result = in1 & in2; // and
            4'b0101: result = in1 | in2; // or
            4'b0110: result = in1 ^ in2; // xor
            
            4'b1000: result = sub; // sub
            4'b1001: result = {31'b0,signed_less}; // slt
            4'b1010: result = {31'b0,signed_less}; // sltu
            default: result = 32'b0; // Mac dinh la 0
        endcase
        zero = (result == 32'b0);
    end
endmodule
