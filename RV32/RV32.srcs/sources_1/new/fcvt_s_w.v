`timescale 1ns/1ps
<<<<<<< HEAD
module fcvt_s_w(
    input  clk, rst_n, valid_input,
    input  signed [31:0] a,
    output reg valid_output,
    output reg [31:0] y
);
    reg v0; reg signed [31:0] a0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v0<=0; a0<=0; end
        else begin v0<=valid_input; a0<=a; end
    end

    wire s0 = a0[31];
    wire [31:0] abz0 = s0 ? (~a0 + 1) : a0;
    wire is_zero0 = (abz0==32'd0);

    reg [31:0] shv0; reg [4:0] lz0;
    always @* begin
        lz0 = 0; shv0 = abz0;
        if (shv0[31:16]==0) begin lz0 = lz0 + 16; shv0 = shv0 << 16; end
        if (shv0[31:24]==0) begin lz0 = lz0 + 8;  shv0 = shv0 << 8;  end
        if (shv0[31:28]==0) begin lz0 = lz0 + 4;  shv0 = shv0 << 4;  end
        if (shv0[31:30]==0) begin lz0 = lz0 + 2;  shv0 = shv0 << 2;  end
        if (shv0[31   ]==0) begin lz0 = lz0 + 1;               end
    end

    reg v1; reg s1; reg is_zero1; reg [7:0] exp1; reg [31:0] norm1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v1<=0; s1<=0; is_zero1<=0; exp1<=0; norm1<=0; end
        else begin
            v1 <= v0;
            s1 <= s0;
            is_zero1 <= is_zero0;
            if (is_zero0) begin
                exp1 <= 8'd0; norm1 <= 32'd0;
            end else begin
                norm1 <= abz0 << lz0;
                exp1  <= 8'd127 + (8'd31 - {3'b000,lz0});
            end
        end
    end

    wire [22:0] f0 = norm1[30:8];
    wire guard  = norm1[7];
    wire sticky = |norm1[6:0];
    wire add_rne = guard & (sticky | f0[0]);
    wire [23:0] fsum = {1'b0,f0} + {23'd0,add_rne};

    reg v2; reg [7:0] exp2; reg [22:0] frac2; reg s2;
    always @* begin
        if (is_zero1) begin
            s2 = s1; exp2 = 8'd0; frac2 = 23'd0;
        end else begin
            s2 = s1;
            if (fsum[23]) begin
                exp2  = exp1 + 1'b1;
                frac2 = fsum[22:0] >> 1;
            end else begin
                exp2  = exp1;
                frac2 = fsum[22:0];
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v2<=0; valid_output<=0; y<=0; end
        else begin
            v2 <= v1;
            y  <= is_zero1 ? 32'd0 : {s2,exp2,frac2};
            valid_output <= v2;
=======
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
>>>>>>> origin/main
        end
    end
endmodule
