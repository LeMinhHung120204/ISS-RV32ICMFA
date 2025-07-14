module ALU(
    input  [3:0]  ALUOp, 
    input  [31:0] in1,
    input  [31:0] in2,
    output reg [31:0] result,
    output reg zero 
);
    wire [31:0] in2_mod = (ALUOp[3]) ? ~in2 : in2; 
    wire [31:0] add_out = in1 + in2_mod + ALUOp[3];

    wire signed_less = (in1[31] == in2[31]) ? add_out[31] : 
                        (ALUOp[1] ? in2[31] : in1[31]);  // ALUOp[1] = 1-SLTU | 0-SLT

    wire [4:0] shamt = in2[4:0];

    always @(*) begin
        case(ALUOp)
            4'b0000: result = add_out; // add
            4'b0001: result = in1 << shamt; // sll
            4'b0010: result = in1 >> shamt; // srl
            4'b0011: result = in1 >>> shamt; // sra
            4'b0100: result = in1 & in2; // and
            4'b0101: result = in1 | in2; // or
            4'b0110: result = in1 ^ in2; // xor
            
            4'b1000: result = add_out; // sub
            4'b1001: result = {31'b0,signed_less}; // slt
            4'b1010: result = {31'b0,signed_less}; // sltu
            default: result = 32'b0; // Mặc định là 0
        endcase
        zero = (result == 32'b0);
    end
endmodule
