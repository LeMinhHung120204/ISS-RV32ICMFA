`timescale 1ns/1ps
module fadd #(
    parameter WIDTH = 32
)(
    input   clk, rst_n, valid_input,
    input   [WIDTH-1:0] a, b,
    output  valid_output,
    output  [WIDTH-1:0] y
);
    reg [3:0]       state;
    localparam [31:0] POS_INF = 32'h7F800000;
    localparam [31:0] NEG_INF = 32'hFF800000;
    localparam  get_input       = 4'd0,
                unpack          = 4'd1,
                special_cases   = 4'd2,
                align           = 4'd3,
                add_0           = 4'd4,
                add_1           = 4'd5,
                normalize_1     = 4'd6,
                normalize_2     = 4'd7,
                round           = 4'd8,
                pack            = 4'd9,
                put_res         = 4'd10;
    
    reg [WIDTH-1:0] a_reg, b_reg, res, reg_oY;
    reg [27:0]      sum;
    reg [26:0]      a_m, b_m;           // {mantissa, guard, round, sticky}
    reg [23:0]      res_m;
    reg [8:0]       a_e, b_e, res_e;
    reg             a_s, b_s, res_s;
    reg             guard, round_bit, sticky, reg_oValid;

    assign y            = reg_oY;
    assign valid_output = reg_oValid;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state       <= get_input;
            a_reg       <= 32'd0;
            b_reg       <= 32'd0;
            res         <= 32'd0;
            reg_oY      <= 32'd0;
            sum         <= 28'd0;
            a_m         <= 27'd0;
            b_m         <= 27'd0;
            res_m       <= 24'd0;
            a_e         <= 9'd0;
            b_e         <= 9'd0;
            res_e       <= 9'd0;
            a_s         <= 1'b0;
            b_s         <= 1'b0;
            res_s       <= 1'b0;
            guard       <= 1'b0;
            round_bit   <= 1'b0;
            sticky      <= 1'b0;
            reg_oValid  <= 1'b0;

        end 
        else begin
            case(state)
                get_input: begin
                    a_reg       <= 32'd0;
                    b_reg       <= 32'd0;
                    res         <= 32'd0;
                    reg_oY      <= 32'd0;
                    sum         <= 28'd0;
                    a_m         <= 27'd0;
                    b_m         <= 27'd0;
                    res_m       <= 24'd0;
                    a_e         <= 9'd0;
                    b_e         <= 9'd0;
                    res_e       <= 9'd0;
                    a_s         <= 1'b0;
                    b_s         <= 1'b0;
                    res_s       <= 1'b0;
                    guard       <= 1'b0;
                    round_bit   <= 1'b0;
                    sticky      <= 1'b0;
                    reg_oValid  <= 1'b0;
                    if (valid_input) begin
                        a_reg <= a;
                        b_reg <= b;
                        state <= unpack;
                    end 
                end 
                unpack: begin
                    a_m   <= {1'b0, a_reg[22:0], 3'b000};
                    b_m   <= {1'b0, b_reg[22:0], 3'b000};
                    a_e   <= a_reg[30:23] - 8'd127;
                    b_e   <= b_reg[30:23] - 8'd127;
                    a_s   <= a_reg[31];
                    b_s   <= b_reg[31];
                    state <= special_cases;
                end 
                special_cases: begin
                    // if a is NaN or b is NaN return NaN (Not a Number)
                    if ((a_e == 128 && a_m !=0) || (b_e == 128 && b_m != 0)) begin
                        // res[31]     <= 1'b1;
                        // res[30:23]  <= 8'd255;
                        // res[22]     <= 1'b1;
                        // res[21:0]   <= 22'd0;
                        res     <= 32'h7FC00000;
                        state   <= put_res;
                    end 

                    // if a is inf return inf
                    else if (a_e == 128) begin
                        // res[31]    <= a_s;
                        // res[30:23] <= 255;
                        // res[22:0]  <= 0;
                        res <= (a_s) ? NEG_INF : POS_INF;

                        //if a is inf and signs don't match return nan
                        if ((b_e == 128) && (a_s != b_s)) begin
                            // res[31]     <= b_s;
                            // res[30:23]  <= 8'd255;
                            // res[22]     <= 1'b1;
                            // res[21:0]   <= 22'd0;
                            res     <= 32'h7FC00000;
                        end
                        state <= put_res;
                    end 

                    //if b is inf return inf
                    else if(b_e == 128) begin
                        // res[31]     <= b_s;
                        // res[30:23]  <= 8'd255;
                        // res[22:0]   <= 23'd0;
                        res     <= (b_s) ? NEG_INF : POS_INF;
                        state   <= put_res;
                    end 

                    //if a, b is zero return b
                    else if(($signed(a_e) == -127) && (a_m == 26'd0) && ($signed(b_e) == -127) && (b_m == 26'd0)) begin
                        res[31]     <= a_s & b_s;
                        res[30:23]  <= b_e[7:0] + 8'd127;
                        res[22:0]   <= b_m[26:3];
                        state       <= put_res;
                    end 

                    //if a is zero return b
                    else if(($signed(a_e) == -127) && (a_m == 26'd0)) begin
                        res[31]     <= b_s;
                        res[30:23]  <= b_e[7:0] + 8'd127;
                        res[22:0]   <= b_m[26:3];
                        state       <= put_res;
                    end 

                    //if b is zero return a
                    else if(($signed(b_e) == -127) && (b_m == 26'd0)) begin
                        res[31]     <= a_s;
                        res[30:23]  <= a_e[7:0] + 8'd127;
                        res[22:0]   <= a_m[26:3];
                        state       <= put_res;
                    end 

                    else begin
                        if ($signed(a_e) == -127) begin
                            a_e     <= -126; // exponent cho subnormal
                        end 
                        else begin
                            a_m[26] <= 1'b1; // them hidden bit neu la normalized
                        end 

                        if ($signed(b_e) == -127) begin
                            b_e     <= -126;
                        end 
                        else begin
                            b_m[26] <= 1'b1;
                        end 
                        state       <= align;
                    end 
                end 
                
                align: begin
                    if ($signed(a_e) > $signed(b_e)) begin
                        b_e     <= b_e + 1'b1;
                        b_m     <= b_m >> 1;
                        b_m[0]  <= b_m[0] | b_m[1];
                    end 
                    else if ($signed(a_e) < $signed(b_e)) begin
                        a_e     <= a_e + 1'b1;
                        a_m     <= a_m >> 1;
                        a_m[0]  <= a_m[0] | a_m[1];
                    end 
                    else begin
                        state <= add_0;
                    end 
                end 

                add_0: begin
                    res_e       <= a_e;
                    if (a_s == b_s) begin
                        sum     <= a_m + b_m;
                        res_s   <= a_s;
                    end 
                    else begin
                        if (a_m >= b_m) begin
                            sum     <= a_m - b_m;
                            res_s   <= a_s;
                        end 
                        else begin
                            sum     <= b_m - a_m;
                            res_s   <= b_s;
                        end 
                    end 
                    state <= add_1;
                end 

                add_1: begin
                    if (sum[27]) begin
                        res_m       <= sum[27:4];
                        guard       <= sum[3];
                        round_bit   <= sum[2];
                        sticky      <= sum[1] | sum[0];
                    end 
                    else begin
                        res_m       <= sum[26:3];
                        guard       <= sum[2];
                        round_bit   <= sum[1];
                        sticky      <= sum[0];
                    end 
                    state <= normalize_1;
                end 

                normalize_1: begin
                    if (res_m[23] == 0 && $signed(res_e) > -126) begin
                        res_e       <= res_e - 1'b1;
                        res_m       <= res_m << 1;
                        res_m[0]    <= guard;
                        guard       <= round_bit;
                        round_bit   <= 1'b0;
                    end 
                    else begin
                        state <= normalize_2;
                    end 
                end

                normalize_2: begin
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
                    else begin
                        state <= pack;
                    end 
                end 

                pack: begin
                    res[22:0]   <= res_m[22:0];
                    res[30:23]  <= res_e[7:0] + 8'd127;
                    res[31]     <= res_s;
                    // return 0
                    if ($signed(res_e) == -126 && res_m[23] == 1'b0) begin
                        res[30:23]  <= 8'd0;
                    end 
                    if ($signed(res_e) == -126 && res_m[23:0] == 24'd0) begin
                        res[31] <= 1'b0;    // -a + a = +0
                    end 

                    if ($signed(res_e) > 127) begin
                        res[22:0]   <= 23'd0;
                        res[30:23]  <= 8'd255;
                        res[31]     <= res_s;
                    end 
                    state   <= put_res;
                end 

                put_res: begin
                    reg_oY      <= res;
                    reg_oValid  <= 1'b1;
                    state       <= get_input;
                end
            endcase
        end 
    end 

endmodule 