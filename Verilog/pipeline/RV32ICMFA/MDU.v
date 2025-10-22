`timescale 1ns/1ps
module MDU #(
    parameter DATA_WIDTH = 32
)(
<<<<<<< HEAD
    input   clk, rst_n, is_high,
=======
    input   clk, rst_n, is_high, valid_input,
>>>>>>> origin/main
    input   [1:0]               Mul_Div_unsigned, 
    input   [1:0]               MulDivOp,
    input   [DATA_WIDTH - 1:0]  rs1, rs2, rd,
    output  [DATA_WIDTH - 1:0]  OutData,
    output  [DATA_WIDTH - 1:0]  oRD,
    output reg stall
);
<<<<<<< HEAD
    localparam num_reg = 8;
    reg [DATA_WIDTH - 1:0] tmp_out;
    reg [DATA_WIDTH - 1:0] hold_rd      [num_reg - 1:0];
    reg [2:0]              hold_funct3  [num_reg - 1:0];
    reg [31:0]             reg_busy;

    wire [DATA_WIDTH - 1:0] E_MulHigh, E_MulLow;
    wire [DATA_WIDTH - 1:0] E_quotient, E_remainder;
=======
    wire [DATA_WIDTH - 1:0] E_MulHigh, E_MulLow;
    wire [DATA_WIDTH - 1:0] E_quotient, E_remainder;
    wire valid_outputMul, valid_outputDiv;

    reg         valid_inputMul, valid_inputDiv; 
    reg [3:0]   oValid_mul;
    reg [7:0]   oValid_div;
    reg [DATA_WIDTH-1:0] hold_rd, tmp_out;

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
        case(MulDivOp)
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
>>>>>>> origin/main

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
<<<<<<< HEAD
    controlMDU controlMDU_inst(
        .clk(clk),
        .rst_n(rst_n),
        .MDU_valid(),
        .is_mul_issue(),
        .funct3(funct3),
        .inRD(rd),

        .mul_done_valid(),
        .mul_done_funct3(),
        .mul_done_rd(),

        .div_done_valid(),
        .div_done_funct3(),
        .div_done_rd(),
        .MDU_is_busy(is_busy)
    );
=======
>>>>>>> origin/main

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

<<<<<<< HEAD
=======
<<<<<<< HEAD
    always @(*) begin
        case(funct3)
            3'd0, 3'd1, 3'd2, 3'd3: begin
                tmp_out = (is_high) ? E_MulHigh : E_MulLow;
            end 
            3'd4, 3'd5: begin
                tmp_out = E_quotient;
            end 
            3'd6, 3'd7: begin
                tmp_out = E_remainder;
            end
            default: tmp_out = 32'd0;
        endcase
    end 
=======
     
>>>>>>> origin/main
>>>>>>> 62aa9b9da2d9756ffc13f8bea73da7974ef85c7c
endmodule