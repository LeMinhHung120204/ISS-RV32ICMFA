`timescale 1ns/1ps
module fdiv #(
    parameter WIDTH = 32
)(
    input   clk, rst_n, valid_input,
    input   [WIDTH-1:0] a, b,
    output  valid_output,
    output  [WIDTH-1:0] y
);
    reg [3:0] state;

    localparam [31:0] POS_INF = 32'h7F800000;
    localparam [31:0] NEG_INF = 32'hFF800000;

    localparam  get_input       = 4'd0,
                unpack          = 4'd1,
                special_cases   = 4'd2,
                normalise_a     = 4'd3,
                normalise_b     = 4'd4,
                divide_0        = 4'd5,
                divide_1        = 4'd6,
                divide_2        = 4'd7,
                divide_3        = 4'd8,
                normalise_1     = 4'd9,
                normalise_2     = 4'd10,
                round           = 4'd11,
                pack            = 4'd12,
                put_res         = 4'd13;

    reg [WIDTH-1:0] reg_a, reg_b, res, reg_oRes;
    reg [50:0]      quotient, divisor, dividend, remainder;
    reg [23:0]      a_m, b_m, res_m;
    reg [9:0]       a_e, b_e, res_e;
    reg [5:0]       count;
    reg             a_s, b_s, res_s;
    reg             guard, round_bit, sticky, reg_oValid;

    assign y            = reg_oRes;
    assign valid_output = reg_oValid;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            quotient    <= 51'd0;
            divisor     <= 51'd0;
            dividend    <= 51'd0;
            remainder   <= 51'd0;
            reg_a       <= 32'd0;
            reg_b       <= 32'd0;
            res         <= 32'd0;
            reg_oRes    <= 32'd0;
            a_m         <= 24'd0;
            b_m         <= 24'd0;
            res_m       <= 24'd0;
            a_e         <= 10'd0;
            b_e         <= 10'd0;
            res_e       <= 10'd0;
            count       <= 6'd0;
            a_s         <= 1'b0;
            b_s         <= 1'b0;
            res_s       <= 1'b0;
            guard       <= 1'b0;
            round_bit   <= 1'b0;
            sticky      <= 1'b0;
            reg_oValid  <= 1'b0;
            state       <= get_input;
        end 
        else begin
            case(state)
                get_input: begin
                    quotient    <= 51'd0;
                    divisor     <= 51'd0;
                    dividend    <= 51'd0;
                    remainder   <= 51'd0;
                    reg_a       <= 32'd0;
                    reg_b       <= 32'd0;
                    res         <= 32'd0;
                    reg_oRes    <= 32'd0;
                    a_m         <= 24'd0;
                    b_m         <= 24'd0;
                    res_m       <= 24'd0;
                    a_e         <= 10'd0;
                    b_e         <= 10'd0;
                    res_e       <= 10'd0;
                    count       <= 6'd0;
                    a_s         <= 1'b0;
                    b_s         <= 1'b0;
                    res_s       <= 1'b0;
                    guard       <= 1'b0;
                    round_bit   <= 1'b0;
                    sticky      <= 1'b0;
                    reg_oValid  <= 1'b0;
                    if (valid_input) begin
                        reg_a   <= a;
                        reg_b   <= b;
                        state   <= unpack;
                    end 
                end 

                unpack: begin
                    a_m     <= {1'b0, reg_a[22:0]};
                    b_m     <= {1'b0, reg_b[22:0]};
                    a_e     <= reg_a[30:23] - 10'd127;
                    b_e     <= reg_b[30:23] - 10'd127;
                    a_s     <= reg_a[31];
                    b_s     <= reg_b[31];
                    state   <= special_cases;
                end 

                special_cases: begin
                    // if a is NaN or b is NaN return NaN
                    if ((a_e == 10'd128 && a_m != 24'd0) || (b_e == 10'd128 && b_m != 24'd0)) begin
                        res     <= 32'h7FC00000;
                        state   <= put_res;
                    end 

                    // if a is inf and b is inf return NaN
                    else if ((a_e == 10'd128) && (b_e == 10'd128)) begin
                        res     <= 32'h7FC00000;
                        state   <= put_res;
                    end 

                    // if a is inf return inf
                    else if (a_e == 10'd128) begin
                        res <= (a_s ^ b_s) ? NEG_INF : POS_INF;

                        // if b is zero return NaNres     <= 32'h7FC00000;
                        if ($signed(b_e == -127) && (b_m == 24'd0)) begin
                            res <= 32'h7FC00000;
                        end 
                        state   <= put_res;
                    end 

                    // if b is inf return zero
                    else if (b_e == 128) begin
                        res[31]     <= a_s ^ b_s;
                        res[30:0]   <= 31'd0;
                        state       <= put_res;
                    end 

                    // if a is zero return zero
                    else if (($signed(a_e) == -127) && (a_m == 24'd0)) begin
                        res[31]     <= a_s ^ b_s;
                        res[30:0]   <= 31'd0;
                        state       <= put_res;
                    end 

                    // if b is zero return NaN
                    else if (($signed(b_e) == -127) && (b_m == 24'd0)) begin
                        res     <= 32'h7FC00000;
                        state   <= put_res;
                    end 

                    else begin
                        if ($signed(a_e) == -127) begin
                            a_e <= -126;
                        end 
                        else begin
                            a_m[23] <= 1'b1;
                        end 

                        if ($signed(b_e) == -127) begin
                            b_e <= -126;
                        end 
                        else begin
                            b_m[23] <= 1'b1;
                        end 
                        state <= normalise_a;
                    end 
                end 

                normalise_a: begin
                    if (a_m[23]) begin
                        state <= normalise_b;
                    end 
                    else begin
                        a_m <= a_m << 1;
                        a_e <= a_e - 1'b1;
                    end 
                end 

                normalise_b: begin
                    if (b_m[23]) begin
                        state <= divide_0;
                    end 
                    else begin
                        b_m <= b_m << 1;
                        b_e <= b_e - 1'b1;
                    end 
                end 

                divide_0: begin
                    res_s       <= a_s ^ b_s;
                    res_e       <= a_e - b_e;
                    quotient    <= 51'd0;
                    remainder   <= 51'd0;
                    dividend    <= a_m << 27;
                    divisor     <= b_m;
                    state       <= divide_1;
                end 

                divide_1: begin
                    quotient        <= quotient << 1;
                    remainder       <= remainder << 1;
                    remainder[0]    <= dividend[50];
                    dividend        <= dividend << 1;
                    state           <= divide_2;
                end 

                divide_2: begin
                    if (remainder >= divisor) begin
                        quotient[0] <= 1'b1;
                        remainder   <= remainder - divisor;
                    end 
                    if (count == 6'd49) begin
                        state   <= divide_3;
                    end 
                    else begin
                        count <= count + 1'b1;
                        state <= divide_1;
                    end 
                end 

                divide_3: begin
                    res_m       <= quotient[26:3];
                    guard       <= quotient[2];
                    round_bit   <= quotient[1];
                    sticky      <= quotient[0] | (remainder != 51'd0);
                    state       <= normalise_1;
                end 

                normalise_1: begin
                    if (res_m[23] == 1'b0 && $signed(res_e) > -126) begin
                        res_e       <= res_e - 1'b1;
                        res_m       <= res_m << 1;
                        guard       <= round_bit;
                        round_bit   <= 1'b0;
                    end 
                    else begin
                        state <= normalise_2;
                    end 
                end 

                normalise_2: begin
                    if ($signed(res_e) < -126) begin
                        res_e       <= res_e + 1'b1;
                        res_m       <= res_m >> 1;
                        guard       <= res_m[0];
                        round_bit   <= guard;
                        sticky      <= sticky | round_bit;
                    end 
                    else begin
                        state <= round;
                    end 
                end 

                round: begin
                    if (guard && (round_bit | sticky | res_m[0])) begin
                        res_m <= res_m + 1'b1;
                        if (res_m == 24'hffffff) begin
                            res_e <= res_e + 1'b1;
                        end 
                    end 
                    state <= pack;
                end 

                pack: begin
                    res[22:0]   <= res_m[22:0];
                    res[30:23]  <= res_e[7:0] + 8'd127;
                    res[31]     <= res_s;

                    if ($signed(res_e) > 127) begin
                        res[22:0]   <= 23'd0;
                        res[30:23]  <= 8'd255;
                        res[31]     <= res_s;
                    end 
                    state <= put_res;
                end 

                put_res: begin
                    reg_oRes    <= res;
                    reg_oValid  <= 1'b1;
                    state       <= get_input;
                end 
            endcase
        end 
    end
endmodule