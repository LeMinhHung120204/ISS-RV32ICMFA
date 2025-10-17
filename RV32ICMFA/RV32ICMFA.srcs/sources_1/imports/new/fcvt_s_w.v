`timescale 1ns/1ps
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
        end
    end
endmodule
