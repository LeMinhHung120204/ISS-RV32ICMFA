`timescale 1ns/1ps
module MDU #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_high, valid_input,
    input   [1:0]               Mul_Div_unsigned, 
    input   [2:0]               funct3,
    input   [DATA_WIDTH - 1:0]  rs1, rs2, rd,
    output  [DATA_WIDTH - 1:0]  OutData,
    output  [DATA_WIDTH - 1:0]  oRD,
    output  is_busy
);
    wire [DATA_WIDTH - 1:0] E_MulHigh, E_MulLow;
    wire [DATA_WIDTH - 1:0] E_quotient, E_remainder;
    
    reg [3:0] oValid_mul;
    reg [7:0] oValid_div;

    // always @(posedge clk or negedge rst_n) begin
    //     if (~rst_n) begin
    //         oValid_mul  <= 4'd0;
    //         oValid_div  <= 8'd0;
    //     end 
    //     else begin
    //         case(funct3)
    //             3'd0, 3'd1, 3'd2, 3'd3: begin
    //                 oValid_mul  <= 
    //             end 
    //         endcase
    //     end 
    // end 

    always @(*) begin
        case(funct3)
            3'd0, 3'd1, 3'd2, 3'd3: begin
                tmp_out = (is_high) ? hold_MulHigh[3] : hold_MulLow[3];
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

    mul32 mul_inst(
       .clk(clk),
       .rst_n(rst_n),
       .is_unsigned(Mul_Div_unsigned),
       .a(rs1),
       .b(rs2),
       .R_high(E_MulHigh),
       .R_low(E_MulLow)
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

     
endmodule