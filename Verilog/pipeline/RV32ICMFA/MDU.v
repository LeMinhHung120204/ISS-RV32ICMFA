`timescale 1ns/1ps
module MDU #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_high, valid_input,
    input   [1:0]               Mul_Div_unsigned, 
    input   [1:0]               MulDivControl,
    input   [DATA_WIDTH - 1:0]  rs1, rs2,
    output  [DATA_WIDTH - 1:0]  OutData,
    output done, stall
);
    wire [DATA_WIDTH - 1:0] E_MulHigh, E_MulLow;
    wire [DATA_WIDTH - 1:0] E_quotient, E_remainder;

    reg                     valid_inputMul, valid_inputDiv, reg_stall;
    reg [DATA_WIDTH-1:0]    tmp_out, reg_rs1, reg_rs2;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_stall       <= 1'b0;
            valid_inputMul  <= 1'b0;
            valid_inputDiv  <= 1'b0;
            reg_rs1         <= 32'd0;
            reg_rs2         <= 32'd0;
        end 
        else begin
            if (valid_input) begin
                reg_stall   <= 1'b1;
                reg_rs1     <= rs1;
                reg_rs2     <= rs2;
            end 
            case(MulDivControl)
                2'b00: begin
                valid_inputMul  <= valid_input;
                valid_inputDiv  <= 1'b0;
                end 
                2'b01: begin
                    valid_inputMul  <= 1'b0;
                    valid_inputDiv  <= valid_input;
                end 
                2'b10: begin
                    valid_inputMul  <= 1'b0;
                    valid_inputDiv  <= valid_input;
                end
                default: begin
                    valid_inputMul  <= 1'b0;
                    valid_inputDiv  <= 1'b0;
                end 
            endcase
            if (reg_stall & (valid_outputMul | valid_outputDiv)) begin
                reg_stall <= 1'b0;
            end
        end 
    end 

    assign stall = reg_stall | (valid_input);

    always @(*) begin
        case(MulDivControl)
            2'b00: begin
                tmp_out         = (is_high) ? E_MulHigh : E_MulLow;
            end 
            2'b01: begin
                tmp_out         = E_quotient;
            end 
            2'b10: begin
                tmp_out         = E_remainder;
            end
            default: begin 
                tmp_out = 32'd0;
            end 
        endcase
    end

    assign OutData  = tmp_out;
    assign done     = valid_outputMul | valid_outputDiv;

    mul32 mul_inst(
       .clk(clk),
       .rst_n(rst_n),
       .valid_input(valid_inputMul),
       .is_unsigned(Mul_Div_unsigned),
       .a(reg_rs1),
       .b(reg_rs2),
       .valid_output(valid_outputMul),
       .R_high(E_MulHigh),
       .R_low(E_MulLow)
    );

    non_restore_v2 div_inst(
       .clk(clk),
       .rst_n(rst_n),
       .valid_input(valid_inputDiv),
       .is_unsigned(Mul_Div_unsigned[0]),
       .dividend(reg_rs1),
       .divisor(reg_rs2),
       .valid_output(valid_outputDiv),
       .quotient(E_quotient),
       .remainder(E_remainder)
    );
endmodule