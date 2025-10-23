`timescale 1ns/1ps
module MDU #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_high, valid_input,
    input   [1:0]               Mul_Div_unsigned, 
    input   [1:0]               MulDivControl,
    input   [DATA_WIDTH - 1:0]  rs1, rs2, rd,
    output  [DATA_WIDTH - 1:0]  OutData,
    output  [DATA_WIDTH - 1:0]  oRD,
    output reg stall
);
    wire [DATA_WIDTH - 1:0] E_MulHigh, E_MulLow;
    wire [DATA_WIDTH - 1:0] E_quotient, E_remainder;

    reg                     valid_inputMul, valid_inputDiv; 
    reg [DATA_WIDTH-1:0]    hold_rd, tmp_out;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            stall   <= 1'b0;
            hold_rd <= 32'd0;
        end 
        else begin
            if (valid_input) begin
                stall   <= 1'b1;
                hold_rd <= rd;
            end 
            if (stall & (valid_outputMul | valid_outputDiv)) begin
                stall   <= 1'b0;
            end 
        end 
    end 

    always @(*) begin
        case(MulDivControl)
            2'b00: begin
                tmp_out         = (is_high) ? E_MulHigh : E_MulLow;
                valid_inputMul  = valid_input;
                valid_inputDiv  = 1'b0;
            end 
            2'b01: begin
                tmp_out         = E_quotient;
                valid_inputMul  = 1'b0;
                valid_inputDiv  = valid_input;
            end 
            2'b10: begin
                tmp_out         = E_remainder;
                valid_inputMul  = 1'b0;
                valid_inputDiv  = valid_input;
            end
            default: begin 
                tmp_out = 32'd0;
                valid_inputMul  = 1'b0;
                valid_inputDiv  = 1'b0;
            end 
        endcase
    end

    assign oRD      = hold_rd;
    assign OutData  = tmp_out;

    mul32 mul_inst(
       .clk(clk),
       .rst_n(rst_n),
       .valid_input(valid_inputMul),
       .is_unsigned(Mul_Div_unsigned),
       .a(rs1),
       .b(rs2),
       .valid_output(valid_outputMul),
       .R_high(E_MulHigh),
       .R_low(E_MulLow)
    );

    non_restore_v2 div_inst(
       .clk(clk),
       .rst_n(rst_n),
       .valid_input(valid_inputDiv),
       .is_unsigned(Mul_Div_unsigned[0]),
       .dividend(rs1),
       .divisor(rs2),
       .valid_output(valid_outputDiv),
       .quotient(E_quotient),
       .remainder(E_remainder)
    );
endmodule