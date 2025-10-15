`timescale 1ns / 1ps
module fclass #(
    parameter WIDTH = 32
)(
    input   [WIDTH-1:0] a,
    output  [WIDTH-1:0] out
);
    localparam  NEG_INF     =10'd1,
                NEG_NORM    =10'd2,
                NEG_SUB     =10'd4,
                NEG_ZERO    =10'd8,
                POS_ZERO    =10'd16,
                POS_SUB     =10'd32,
                POS_NORM    =10'd64,
                POS_INF     =10'd128,
                SNAN        =10'd256,
                QNAN        =10'd512;

    wire        s = a[31];
    wire [7:0]  e = a[30:23];
    wire [22:0] f = a[22:0];

    wire is_inf  = (e == 8'hFF) && (f == 23'd0);
    wire is_nan  = (e == 8'hFF) && (f != 23'd0);
    wire is_qnan = is_nan && f[22];               // MSB payload = 1
    wire is_snan = is_nan && !f[22];              // MSB payload = 0 (va f!=0 đa bao trum)
    wire is_zero = (e == 8'd0) && (f == 23'd0);
    wire is_sub  = (e == 8'd0) && (f != 23'd0);
    wire is_norm = (e != 8'd0) && (e != 8'hFF);   // con lai

    reg [9:0] mask;
    always @(*) begin
        if (is_qnan)        mask = QNAN;
        else if (is_snan)   mask = SNAN;
        else if (is_inf)    mask = s ? NEG_INF  : POS_INF;
        else if (is_zero)   mask = s ? NEG_ZERO : POS_ZERO;
        else if (is_sub)    mask = s ? NEG_SUB  : POS_SUB;
        else                mask = s ? NEG_NORM : POS_NORM; // is_norm
    end

    assign out = {22'b0, mask};
endmodule 