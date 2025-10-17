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

    reg v1; reg s1; reg [31:0] abz1; reg is_zero1;
    reg [4:0] lz1;
    always @* begin
        s1 = a0[31];
        abz1 = a0[31] ? (~a0 + 1) : a0;
        is_zero1 = (abz1==32'd0);
    end
    reg [31:0] shv; reg [4:0] lz;
    always @* begin
        lz = 0; shv = abz1;
        if (shv[31:16]==0) begin lz = lz + 16; shv = shv << 16; end
        if (shv[31:24]==0) begin lz = lz + 8;  shv = shv << 8;  end
        if (shv[31:28]==0) begin lz = lz + 4;  shv = shv << 4;  end
        if (shv[31:30]==0) begin lz = lz + 2;  shv = shv << 2;  end
        if (shv[31   ]==0) begin lz = lz + 1;               end
    end
    reg [7:0] exp1; reg [31:0] norm1; reg [22:0] frac1; reg rnd_carry1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v1<=0; exp1<=0; norm1<=0; frac1<=0; rnd_carry1<=0; s1<=0; is_zero1<=0; end
        else begin
            v1 <= v0;
            if (is_zero1) begin
                exp1 <= 0; norm1 <= 0; frac1 <= 0; rnd_carry1<=0;
            end else begin
                norm1 <= abz1 << lz;
                exp1  <= 8'd127 + (8'd31 - {3'b000,lz});
            end
        end
    end

    reg v2; reg [7:0] exp2; reg [22:0] frac2; reg s2;
    always @* begin
        if (is_zero1) begin
            s2 = s1; exp2 = 8'd0; frac2 = 23'd0;
        end else begin
            s2 = s1;
            begin
                wire [22:0] f0 = norm1[30:8];
                wire guard = norm1[7];
                wire sticky = |norm1[6:0];
                wire add = guard & (sticky | f0[0]);
                wire [23:0] fsum = {1'b0,f0} + add;
                if (fsum[23]) begin
                    exp2  = exp1 + 1'b1;
                    frac2 = fsum[22:0] >> 1;
                end else begin
                    exp2  = exp1;
                    frac2 = fsum[22:0];
                end
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v2<=0; y<=0; valid_output<=0; end
        else begin
            v2 <= v1;
            y  <= (is_zero1) ? 32'd0 : {s2,exp2,frac2};
            valid_output <= v2;
        end
    end
endmodule
