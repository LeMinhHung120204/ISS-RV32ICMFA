`timescale 1ns/1ps
module MDU #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_high,
    input   [1:0]               Mul_Div_unsigned, 
    input   [2:0]               funct3,
    input   [DATA_WIDTH - 1:0]  rs1, rs2, rd,
    output  [DATA_WIDTH - 1:0]  OutData,
    output  [DATA_WIDTH - 1:0]  oRD,
    output  is_busy
);
    localparam num_reg = 8;
    reg [DATA_WIDTH - 1:0] tmp_out;
    reg [DATA_WIDTH - 1:0] hold_rd      [num_reg - 1:0];
    reg [2:0]              hold_funct3  [num_reg - 1:0];
    reg [31:0]             reg_busy;

    wire [DATA_WIDTH - 1:0] E_MulHigh, E_MulLow;
    wire [DATA_WIDTH - 1:0] E_quotient, E_remainder;

    mul32 mul_inst(
       .clk(clk),
       .rst_n(rst_n),
       .is_unsigned(Mul_Div_unsigned),
       .a(rs1),
       .b(rs2),
       .R_high(E_MulHigh),
       .R_low(E_MulLow)
    );
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

    non_restore_v2 div_inst(
       .clk(clk),
       .rst_n(rst_n),
       .is_unsigned(Mul_Div_unsigned[0]),
       .dividend(rs1),
       .divisor(rs2),
       .quotient(E_quotient),
       .remainder(E_remainder)
    );

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
endmodule