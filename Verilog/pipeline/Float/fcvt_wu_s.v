`timescale 1ns/1ps
// from Lee Min Hunz with luv
module fcvt_wu_s(
    input  clk, rst_n, valid_input
,   input  [31:0] a
,   output reg valid_output
,   output reg [31:0] y
);
    reg [31:0]  a0, y2;
    reg [23:0]  m1; 
    reg [7:0]   e1; 
    reg v1, s1, is_zero1, is_naninf1, v0;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            v0  <= 0; 
            a0  <= 0; 
        end
        else if (valid_input) begin 
            v0  <= valid_input; 
            a0  <= a; 
        end
    end

    wire s0         = a0[31];
    wire [7:0] e0   = a0[30:23];
    wire [22:0] f0  = a0[22:0];
    wire is_zero0   = (e0==8'd0) && (f0==23'd0);
    wire is_naninf0 = (e0==8'd255);
    wire [23:0] m0  = (e0==8'd0) ? {1'b0,f0} : {1'b1,f0};

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            v1          <= 0; 
            s1          <= 0; 
            e1          <= 0; 
            m1          <= 0; 
            is_zero1    <= 0; 
            is_naninf1  <= 0; 
        end
        else begin
            v1          <= v0; 
            s1          <= s0; 
            e1          <= e0; 
            m1          <= m0; 
            is_zero1    <= is_zero0; 
            is_naninf1  <= is_naninf0;
        end
    end

    wire [8:0] shift            = (e1>=8'd127) ? (e1-8'd127) : 9'd0;
    wire [31:0] left_shifted    = (shift>=9'd23) ? ( {m1,9'd0} << (shift-9'd23) ) : 32'd0;
    wire [31:0] right_shifted   = (shift< 9'd23) ? ( m1 >> (9'd23-shift) ) : 32'd0;
    wire use_left               = (shift>=9'd23);
    wire [31:0] mag_u           = use_left ? left_shifted : right_shifted;

    always @(*) begin
        if (is_naninf1) begin
            y2 = s1 ? 32'd0 : 32'hFFFFFFFF;
        end else if (is_zero1) begin
            y2 = 32'd0;
        end else if (s1) begin
            y2 = 32'd0;
        end else begin
            if (mag_u[31]) y2 = 32'hFFFFFFFF;
            else y2 = mag_u;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y               <= 32'd0;
            valid_output    <= 1'b0;
        end else begin
            y               <= y2;
            valid_output    <= v1;
        end
    end
endmodule
