`timescale 1ns/1ps
module fcvt_s_wu #(
    parameter WIDTH = 32
)(
    input clk, rst_n, valid_input,
    input [WIDTH-1:0] a,           // Số nguyên không dấu 32-bit
    output valid_output,
    output [WIDTH-1:0] y           // Kết quả float
);
    reg [3:0] state;
    localparam GET_INPUT = 4'd0, CONVERT = 4'd1, PACK = 4'd2, DONE = 4'd3;
    reg [WIDTH-1:0] a_reg;
    reg [7:0] exp_reg;
    reg [22:0] mant_reg;
    reg sign, guard, round_bit, sticky;
    reg [31:0] abs_val;
    reg [23:0] mant_24;
    reg [WIDTH-1:0] reg_oY;
    reg reg_oValid;
    reg [4:0] pos;
    integer k;
    assign valid_output = reg_oValid;
    assign y = reg_oY;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= GET_INPUT;
            reg_oValid <= 1'b0;
            reg_oY <= 0;
            a_reg <= 0; exp_reg <= 0; mant_reg <= 0; sign <= 0;
            guard <= 0; round_bit <= 0; sticky <= 0;
            abs_val <= 0; mant_24 <= 0; pos <= 0;
        end else begin
            case (state)
                GET_INPUT: begin
                    reg_oValid <= 1'b0;
                    if (valid_input) begin
                        a_reg <= a;
                        state <= CONVERT;
                    end
                end
                CONVERT: begin
                    if (a_reg == 32'd0) begin
                        sign <= 1'b0;
                        exp_reg <= 8'd0;
                        mant_reg <= 23'd0;
                    end else begin
                        sign <= 1'b0;           // Kết quả luôn dương
                        abs_val <= a_reg;       // Giá trị tuyệt đối chính là a_reg
                        pos = 5'd0;
                        for (k = 0; k < 32; k = k+1)
                            if (abs_val[k]) pos = k;
                        exp_reg <= pos + 8'd127;
                        if (pos > 23) begin
                            mant_24 <= abs_val >> (pos - 23);
                            mant_reg <= mant_24[22:0];
                            guard <= abs_val[pos - 24];
                            round_bit <= (pos > 24) ? abs_val[pos - 25] : 1'b0;
                            sticky <= 1'b0;
                            for (k = 0; k < pos - 24; k = k+1)
                                sticky <= sticky | abs_val[k];
                            if (guard && (round_bit || sticky || mant_reg[0])) begin
                                mant_24 <= mant_24 + 24'd1;
                                if (mant_24[23]) begin
                                    mant_reg <= 23'd0;
                                    exp_reg <= exp_reg + 8'd1;
                                end else begin
                                    mant_reg <= mant_24[22:0];
                                end
                            end
                        end else begin
                            mant_reg <= abs_val[22:0] << (23 - pos);
                        end
                    end
                    state <= PACK;
                end
                PACK: begin
                    reg_oY <= {sign, exp_reg, mant_reg};
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