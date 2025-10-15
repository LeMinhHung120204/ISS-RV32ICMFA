`timescale 1ns/1ps
module fmin #(
    parameter WIDTH = 32
)(
    input   [WIDTH-1:0] a, b,
    output reg  [WIDTH-1:0] out,
    output reg  exception
);
    localparam [31:0] QNAN = 32'h7FC00000; // quiet NaN
    wire        sa, sb;
    wire [7:0]  ea, eb;
    wire [22:0] fa, fb;

    wire a_is_snan; 
    wire b_is_snan; 
    wire a_is_zero;
    wire b_is_zero;

    wire a_is_nan;
    wire b_is_nan;

    wire a_mag_lt;
    wire a_mag_gt;

    assign sa = a[31];
    assign sb = b[31];
    assign ea = a[30:23];
    assign eb = b[30:23];
    assign fa = a[22:0];
    assign fb = b[22:0];

    assign a_is_nan     = (ea == 8'hFF) && (fa != 23'd0);
    assign b_is_nan     = (eb == 8'hFF) && (fb != 23'd0);

    assign a_is_snan    = a_is_nan && (fa[22] == 1'b0); 
    assign b_is_snan    = b_is_nan && (fb[22] == 1'b0);

    assign a_is_zero    = (ea == 8'd0) && (fa == 23'd0);
    assign b_is_zero    = (eb == 8'd0) && (fb == 23'd0);

    assign a_mag_lt     = (ea < eb) || ((ea == eb) && (fa < fb));
    assign a_mag_gt     = (ea > eb) || ((ea == eb) && (fa > fb));

    always @(*) begin
        out         = 32'd0;
        exception   = 1'b0;
        // 1) NaN case
        if (a_is_nan && b_is_nan) begin
            // Ca hai NaN -> NaN chuan, bat exception
            out       = QNAN;
            exception = a_is_snan | b_is_snan;
        end
        else if (a_is_nan) begin
            // a la NaN -> b
            out       = b;
            exception = a_is_snan; // bat neu la signaling NaN
        end
        else if (b_is_nan) begin
            // b la NaN -> a
            out       = a;
            exception = b_is_snan; // bat neu la signaling NaN
        end
        else begin
            // 2) xu ly ±0 truoc
            if (a_is_zero && b_is_zero) begin
                // min(+0, -0) = -0; min(+0, +0)=+0; min(-0, -0)=-0
                out = (sa | sb) ? 32'h8000_0000 : 32'h0000_0000;
            end
            // 3) Khac dau: số am < so duonng
            else if (sa ^ sb) begin
                out = sa ? a : b;
            end
            else begin
                // 4) Cung dau: dung magnitude + quy tac dao cho số âm
                if (sa) begin
                    // Cung am: magnitude lon hơn -> gia tri thuc nho hon
                    if (a_mag_gt)       out = a;
                    else if (a_mag_lt)  out = b;
                    else                out = a; // bang nhau
                end
                else begin
                    // Cung duonng: magnitude nho hơn -> giá trị nho hon
                    if (a_mag_lt)       out = a;
                    else if (a_mag_gt)  out = b;
                    else                out = a; // bang nhau
                end
            end
        end
    end
endmodule 