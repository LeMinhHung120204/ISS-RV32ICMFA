`timescale 1ns/1ps
module fcvt_s_w #(
    parameter WIDTH = 32
)(
    input clk, rst_n, valid_input,
    input [WIDTH-1:0] a,           // Số nguyên có dấu 32-bit
    output valid_output,
    output [WIDTH-1:0] y           // Kết quả float (IEEE-754 single)
);
    // Trạng thái FSM
    reg [3:0] state;
    localparam GET_INPUT = 4'd0, CONVERT = 4'd1, PACK = 4'd2, DONE = 4'd3;
    // Thanh ghi nội bộ
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
            // Reset FSM và thanh ghi
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
                        // Trường hợp 0 đặc biệt
                        sign <= 1'b0;
                        exp_reg <= 8'd0;
                        mant_reg <= 23'd0;
                    end else begin
                        // Tính dấu và giá trị tuyệt đối
                        sign <= a_reg[31];
                        abs_val <= a_reg[31] ? (~a_reg + 1) : a_reg;
                        // Tìm vị trí bit 1 cao nhất
                        pos = 5'd0;
                        for (k = 0; k < 32; k = k+1)
                            if (abs_val[k]) pos = k;
                        exp_reg <= pos + 8'd127;  // exponent = pos + bias
                        // Tính mantissa và các bit làm tròn
                        if (pos > 23) begin
                            // Dịch phải để vừa 1.mantissa
                            mant_24 <= abs_val >> (pos - 23);
                            mant_reg <= mant_24[22:0];
                            guard <= abs_val[pos - 24];
                            round_bit <= (pos > 24) ? abs_val[pos - 25] : 1'b0;
                            // Sticky = OR của các bit thấp hơn guard
                            sticky <= 1'b0;
                            for (k = 0; k < pos - 24; k = k+1)
                                sticky <= sticky | abs_val[k];
                            // Làm tròn đến gần nhất (ties-even)
                            if (guard && (round_bit || sticky || mant_reg[0])) begin
                                mant_24 <= mant_24 + 24'd1;
                                if (mant_24[23]) begin
                                    // Overflow mantissa
                                    mant_reg <= 23'd0;
                                    exp_reg <= exp_reg + 8'd1;
                                end else begin
                                    mant_reg <= mant_24[22:0];
                                end
                            end
                        end else begin
                            // Dịch trái nếu bit cao nhất <= 23
                            mant_reg <= abs_val[22:0] << (23 - pos);
                        end
                    end
                    state <= PACK;
                end
                PACK: begin
                    // Ghép {sign, exponent, mantissa}
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
