`timescale 1ns/1ps
module fcvt_w_s(
    input  clk, rst_n, valid_input,
    input  [31:0] a,
    output reg valid_output,
    output reg signed [31:0] y
);
    reg v0; reg [31:0] a0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v0<=0; a0<=0; end
        else begin v0<=valid_input; a0<=a; end
    end

    wire s0 = a0[31];
    wire [7:0] e0 = a0[30:23];
    wire [22:0] f0 = a0[22:0];
    wire is_zero0 = (e0==8'd0) && (f0==23'd0);
    wire is_naninf0 = (e0==8'd255);
    wire [23:0] m0 = (e0==8'd0) ? {1'b0,f0} : {1'b1,f0};

    reg v1; reg s1; reg [7:0] e1; reg [23:0] m1; reg is_zero1; reg is_naninf1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v1<=0; s1<=0; e1<=0; m1<=0; is_zero1<=0; is_naninf1<=0; end
        else begin
            v1<=v0; s1<=s0; e1<=e0; m1<=m0; is_zero1<=is_zero0; is_naninf1<=is_naninf0;
        end
    end

    wire [8:0] shift = (e1>=8'd127) ? (e1-8'd127) : 9'd0;
    wire [31:0] left_shifted  = (shift>=9'd23) ? ( {m1,9'd0} << (shift-9'd23) ) : 32'd0;
    wire [31:0] right_shifted = (shift< 9'd23) ? ( m1 >> (9'd23-shift) ) : 32'd0;
    wire use_left  = (shift>=9'd23);
    wire [31:0] mag_u = use_left ? left_shifted : right_shifted;

    reg v2; reg signed [31:0] y2;
    always @* begin
        if (is_naninf1) begin
            y2 = s1 ? -32'sd2147483648 : 32'sd2147483647;
        end else if (is_zero1) begin
            y2 = 32'sd0;
        end else begin
            if (s1) begin
                if (mag_u[31]) y2 = -32'sd2147483648;
                else y2 = -$signed(mag_u);
            end else begin
                if (mag_u[31]) y2 = 32'sd2147483647;
                else y2 = $signed(mag_u);
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v2<=0; valid_output<=0; y<=0; end
        else begin
            v2 <= v1;
            y  <= y2;
            valid_output <= v2;
        end
    end
endmodule
