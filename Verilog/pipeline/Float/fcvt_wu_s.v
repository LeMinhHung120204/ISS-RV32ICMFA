`timescale 1ns/1ps
module fcvt_wu_s(
    input  clk, rst_n, valid_input,
    input  [31:0] a,
    output reg valid_output,
    output reg [31:0] y
);
    reg v0; reg [31:0] a0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v0<=0; a0<=0; end
        else begin v0<=valid_input; a0<=a; end
    end

    wire s = a0[31];
    wire [7:0] efield = a0[30:23];
    wire [22:0] ffield = a0[22:0];
    wire is_zero = (efield==8'd0) && (ffield==23'd0);
    wire is_naninf = (efield==8'd255);
    wire [23:0] mant = (efield==8'd0) ? {1'b0,ffield} : {1'b1,ffield};
    reg v1; reg s1; reg [7:0] e1; reg [23:0] m1; reg is_zero1; reg is_naninf1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v1<=0; s1<=0; e1<=0; m1<=0; is_zero1<=0; is_naninf1<=0; end
        else begin
            v1<=v0; s1<=s; e1<=efield; m1<=mant; is_zero1<=is_zero; is_naninf1<=is_naninf;
        end
    end

    reg v2; reg [31:0] y2;
    always @* begin
        if (is_naninf1) begin
            if (s1) y2 = 32'd0;
            else    y2 = 32'hFFFFFFFF;
        end else if (is_zero1) begin
            y2 = 32'd0;
        end else if (s1) begin
            y2 = 32'd0;
        end else begin
            integer shift;
            reg [31:0] val_u;
            if (e1 < 8'd127) begin
                val_u = 32'd0;
            end else begin
                shift = e1 - 8'd127;
                if (shift >= 23) val_u = m1 << (shift-23);
                else val_u = m1 >> (23 - shift);
            end
            if (|val_u[31:31]) y2 = 32'hFFFFFFFF;
            else y2 = val_u;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v2<=0; y<=0; valid_output<=0; end
        else begin
            v2 <= v1;
            y  <= y2;
            valid_output <= v2;
        end
    end
endmodule
