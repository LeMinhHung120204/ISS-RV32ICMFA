`timescale 1ns/1ps
module MDU #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_high, valid_input,
    input   [1:0]                   Mul_Div_unsigned, 
    input   [1:0]                   MulDivControl,
    input   [DATA_WIDTH - 1:0]      rs1, rs2,
    output reg [DATA_WIDTH - 1:0]   OutData,
    output done,
    output stall
);
    localparam IDLE = 0, START = 1, DONE = 2;
    reg     [1:0]               state, next_state;
    wire    [DATA_WIDTH - 1:0]  E_MulHigh, E_MulLow;
    wire    [DATA_WIDTH - 1:0]  E_quotient, E_remainder;
    wire    mul_busy, div_busy;

    reg                         valid_inputMul, valid_inputDiv, reg_stall;
    reg     [1:0]               reg_control;
    reg     [DATA_WIDTH-1:0]    reg_rs1, reg_rs2, A, B;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
        end 
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            IDLE: begin
                if (valid_input) begin
                    next_state = START;
                end 
                else begin
                    next_state = IDLE;
                end 
            end 
            START: begin
                if (done) begin
                    next_state = IDLE;
                end 
                else begin
                    next_state = START;
                end 
            end 
            default: begin
                next_state = IDLE;
            end 
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_rs1     <= 32'd0;
            reg_rs2     <= 32'd0;
            reg_stall   <= 1'b0;
        end 
        else begin
            if (valid_input) begin
                reg_rs1     <= rs1;
                reg_rs2     <= rs2;
                reg_stall   <= 1'b1;
                if (done) begin
                    reg_stall <= 1'b0;
                end 
            end
        end
    end

    assign done = valid_outputDiv | valid_outputMul;
    assign stall = ((mul_busy | div_busy | valid_input) & (~done));

    always @(*) begin
        case(MulDivControl)
            2'b00: begin
                valid_inputMul = valid_input;
                valid_inputDiv = 1'b0;
                OutData         = (is_high) ? E_MulHigh : E_MulLow;
            end 
            2'b01, 2'b10: begin
                valid_inputMul = 1'b0;
                valid_inputDiv = valid_input;
                OutData         = (MulDivControl == 2'b01) ? E_quotient : E_remainder;
            end 
            default: begin
                valid_inputMul = 1'b0;
                valid_inputDiv = 1'b0;
                OutData        = 32'd0;
            end
        endcase
    end 
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