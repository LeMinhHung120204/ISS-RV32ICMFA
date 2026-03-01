`timescale 1ns/1ps
module MDU #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_high, valid_input
,   input   [1:0]                   Mul_Div_unsigned 
,   input   [1:0]                   MulDivControl
,   input   [DATA_WIDTH - 1:0]      rs1, rs2
,   output reg [DATA_WIDTH - 1:0]   OutData
    // output done,
,   output stall
);

    // ================================================================
    // INTERNAL WIRES
    // ================================================================
    wire    [DATA_WIDTH - 1:0]  E_MulHigh, E_MulLow;
    wire    [DATA_WIDTH - 1:0]  E_quotient, E_remainder;
    wire    mul_busy, div_busy, done;

    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    reg                         valid_inputMul, valid_inputDiv;
    reg     [1:0]               reg_control;
    reg     [DATA_WIDTH-1:0]    A, B;

    // ================================================================
    // STALL LOGIC
    // ================================================================
    assign done = valid_outputDiv | valid_outputMul;
    assign stall = ((mul_busy | div_busy | valid_input) & (~done));

    // ================================================================
    // OUTPUT MUX
    // ================================================================
    always @(*) begin
        case(MulDivControl)
            2'b00: begin
                valid_inputMul  = valid_input;
                valid_inputDiv  = 1'b0;
                OutData         = (is_high) ? E_MulHigh : E_MulLow;
            end 
            2'b01: begin
                valid_inputMul  = 1'b0;
                valid_inputDiv  = valid_input;
                OutData         = E_quotient;
            end 
            2'b10: begin
                valid_inputMul  = 1'b0;
                valid_inputDiv  = valid_input;
                OutData         = E_remainder;
            end
            default: begin
                valid_inputMul = 1'b0;
                valid_inputDiv = 1'b0;
                OutData        = 32'd0;
            end
        endcase
    end

    // ================================================================
    // MULTIPLIER INSTANTIATION
    // ================================================================
    mul32 mul_inst(
       .clk(clk),
       .rst_n(rst_n),
       .valid_input(valid_inputMul),
       .is_unsigned(Mul_Div_unsigned),
       .a(rs1),
       .b(rs2),
       .valid_output(valid_outputMul),
       .R_high(E_MulHigh),
       .R_low(E_MulLow),
       .is_busy(mul_busy)
    );

    // ================================================================
    // DIVIDER INSTANTIATION
    // ================================================================
    non_restore div_inst(
       .clk(clk),
       .rst_n(rst_n),
       .valid_input(valid_inputDiv),
       .is_unsigned(Mul_Div_unsigned[0]),
       .dividend(rs1),
       .divisor(rs2),
       .valid_output(valid_outputDiv),
       .quotient(E_quotient),
       .remainder(E_remainder),
       .is_busy(div_busy)
    );
endmodule