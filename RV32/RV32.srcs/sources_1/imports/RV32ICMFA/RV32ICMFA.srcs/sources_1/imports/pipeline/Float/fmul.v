`timescale 1ns/1ps
module fmul #(
    parameter WIDTH = 32
)(
    input   clk, rst_n, valid_input,
    input   [WIDTH-1:0] a, b,
    output  valid_output,
    output  [WIDTH-1:0] y
);
    reg [3:0] state;
    localparam  get_input       = 4'd0,
                unpack          = 4'd1,
                special_cases   = 4'd2,
                normalise_a     = 4'd3,
                normalise_b     = 4'd4,
                multiply_0      = 4'd5,
                multiply_1      = 4'd6,
                normalise_1     = 4'd7,
                normalise_2     = 4'd8,
                round           = 4'd9,
                pack            = 4'd10,
                put_z           = 4'd11;
    
    reg [WIDTH-1:0] reg_a, reg_b, res, reg_oRes;
    reg [47:0]      product;   
    reg [23:0]      a_m, b_m, res_m;
    reg [9:0]       a_e, b_e, res_e;
    reg             a_s, b_s, res_s;
    reg             guard, round_bit, sticky, reg_oValid;

    wire [47:0] mul_out;
    wire        mul_done;
    

    assign y            = reg_oRes;
    assign valid_output = reg_oValid;


    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state       <= get_input;
            product     <= 48'd0;
            reg_a       <= 32'd0;
            reg_b       <= 32'd0;
            res         <= 32'd0;
            reg_oRes    <= 32'd0;
            reg_oRes    <= 32'd0;
            a_m         <= 24'd0;
            b_m         <= 24'd0;
            res_m       <= 24'd0;
            a_e         <= 10'd0;
            b_e         <= 10'd0;
            res_e       <= 10'd0;
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
                    product     <= 48'd0;
                    reg_a       <= 32'd0;
                    reg_b       <= 32'd0;
                    res         <= 32'd0;
                    reg_oRes    <= 32'd0;
                    reg_oRes    <= 32'd0;
                    a_m         <= 24'd0;
                    b_m         <= 24'd0;
                    res_m       <= 24'd0;
                    a_e         <= 10'd0;
                    b_e         <= 10'd0;
                    res_e       <= 10'd0;
                    a_s         <= 1'b0;
                    b_s         <= 1'b0;
                    res_s       <= 1'b0;
                    guard       <= 1'b0;
                    round_bit   <= 1'b0;
                    sticky      <= 1'b0;
                    reg_oValid  <= 1'b0;

                    if (valid_input) begin
                        state   <= unpack;
                        reg_a   <= a;
                        reg_b   <= b;
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
                        // res[31]     <= 1'b1;
                        // res[30:23]  <= 8'd255;
                        // res[22]     <= 1'b1;
                        // res[21:0]   <= 22'd0;
                        res     <= 32'h7FC00000;
                        state   <= put_z;
                    end 

                    //if a is inf return inf
                    else if (a_e == 10'd128) begin
                        res[31]     <= a_s ^ b_s;
                        res[30:23]  <= 8'd255;
                        res[22:0]   <= 23'd0;

                        //if b is zero return NaN
                        if (($signed(b_e) == -127) && (b_m == 24'd0)) begin
                            // res[31]     <= 1'b1;
                            // res[30:23]  <= 8'd255;
                            // res[22]     <= 1'b1;
                            // res[21:0]   <= 22'd9;
                            res <= 32'h7FC00000;
                        end 
                        state <= put_z;
                    end 

                    //if b is zero return NaN
                    else if (b_e == 10'd128) begin
                        res[31]     <= a_s ^ b_s;
                        res[30:23]  <= 8'd255;
                        res[22:0]   <= 23'd0;

                        //if a is zero return NaN
                        if (($signed(a_e) == -127) && (a_m == 24'd0)) begin
                            res[31]     <= 1'b1;
                            res[30:23]  <= 8'd255;
                            res[22]     <= 1'b1;
                            res[21:0]   <= 22'd9;
                        end 
                        state <= put_z;
                    end 

                    // if a is zero return zero
                    else if (($signed(a_e) == -127) && (a_m == 24'd0)) begin
                        res[31]     <= a_s ^ b_s;
                        res[30:23]  <= 8'd0;
                        res[22:0]   <= 23'd0;
                        state       <= put_z;
                    end 

                    // if b is zero return zero
                    else if (($signed(b_e) == -127) && (b_m == 24'd0)) begin
                        res[31]     <= a_s ^ b_s;
                        res[30:23]  <= 8'd0;
                        res[22:0]   <= 23'd0;
                        state       <= put_z;
                    end 
                    
                    else begin
                        if ($signed(a_e) == -127) begin // subnormal
                            a_e <= -126;
                        end 
                        else begin
                            a_m[23] <= 1'b1;            // them hidden bit cho normalize
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
                        state <= multiply_0;
                    end 
                    else begin
                        b_m <= b_m << 1;
                        b_e <= b_e - 1'b1;
                    end 
                end 

                multiply_0: begin
                    if (mul_done) begin
                        res_s   <= a_s ^ b_s;
                        res_e   <= a_e + b_e + 1'b1;
                        product <= mul_out;
                        state   <= multiply_1;
                    end 
                end 

                multiply_1: begin
                    res_m       <= product[47:24];
                    guard       <= product[23];
                    round_bit   <= product[22];
                    sticky      <= (product[21:0] != 22'd0);
                    state       <= normalise_1;
                end 

                normalise_1: begin
                    if (res_m[23] == 1'b0) begin
                        res_e       <= res_e - 1'b1;
                        res_m       <= res_m << 1;
                        res_m[0]    <= guard;
                        guard       <= sticky;
                        sticky      <= 1'b0;
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

                    if ($signed(res_e) == -126 && res_m[23] == 1'b0) begin
                        res[30:23] <= 8'd0;
                    end 

                    if ($signed(res_e) > 127) begin
                        res[22:0]   <= 23'd0;
                        res[30:23]  <= 8'd255;
                        res[31]     <= res_s;
                    end 
                    state <= put_z;
                end 

                put_z: begin
                    reg_oValid  <= 1'b1;
                    reg_oRes    <= res;
                    state       <= get_input;
                end 
            endcase
        end 
    end 

    mul24 mul24_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(state == multiply_0),
        .is_unsigned(2'b0),
        .a(a_m),
        .b(b_m),
        .valid_output(mul_done),
        .R(mul_out)
    );
endmodule