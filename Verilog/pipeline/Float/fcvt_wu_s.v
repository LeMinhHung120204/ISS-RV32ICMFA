`timescale 1ns/1ps
module fcvt_wu_s #(
    parameter WIDTH = 32
)(
    input clk, rst_n, valid_input,
    input [WIDTH-1:0] a,           // Số float IEEE-754 single
    output valid_output,
    output [WIDTH-1:0] y           // Kết quả nguyên không dấu
);
    reg [3:0] state;
    localparam GET_INPUT = 4'd0, CONVERT = 4'd1, PACK = 4'd2, DONE = 4'd3;
    reg [WIDTH-1:0] a_reg;
    reg [WIDTH-1:0] result;
    reg [31:0] abs_uint;
    reg reg_oValid;
    reg [WIDTH-1:0] reg_oY;
    integer e;
    assign valid_output = reg_oValid;
    assign y = reg_oY;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= GET_INPUT;
            reg_oValid <= 1'b0;
            reg_oY <= 0;
            a_reg <= 0;
            result <= 32'd0;
            abs_uint <= 32'd0;
        end else begin
            case(state)
                GET_INPUT: begin
                    reg_oValid <= 1'b0;
                    if (valid_input) begin
                        a_reg <= a;
                        state <= CONVERT;
                    end
                end
                CONVERT: begin
                    if (a_reg[31]) begin
                        // Số âm → saturate thành 0
                        result <= 32'd0;
                    end else if (a_reg[30:23] < 8'd127) begin
                        // |value| < 1.0
                        result <= 32'd0;
                    end else begin
                        e = a_reg[30:23] - 8'd127;
                        if (e >= 31) begin
                            // Quá lớn → saturate thành 0xFFFFFFFF
                            result <= 32'hFFFFFFFF;
                        end else begin
                            if (e > 23)
                                abs_uint = (32'd1 << e) | (a_reg[22:0] << (e - 23));
                            else
                                abs_uint = (32'd1 << e) | (a_reg[22:0] >> (23 - e));
                            result <= abs_uint;
                        end
                    end
                    state <= PACK;
                end
                PACK: begin
                    reg_oY <= result;
                    state <= DONE;
                end
                DONE: begin
                    reg_oValid <= 1'b1;
                    state <= GET_INPUT;
                end
            endcase
        end
    end
endmodule