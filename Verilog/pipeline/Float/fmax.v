`timescale 1ns/1ps
module fmax #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0] a, b,
    output reg [WIDTH-1:0] out,
    output reg exception
);
    localparam [31:0] QNAN = 32'h7FC0_0000;

    // Unpack
    wire sa = a[31];
    wire sb = b[31];
    wire [7:0]  ea = a[30:23];
    wire [7:0]  eb = b[30:23];
    wire [22:0] fa = a[22:0];
    wire [22:0] fb = b[22:0];

    wire a_is_nan  = (ea == 8'hFF) && (fa != 23'd0);
    wire b_is_nan  = (eb == 8'hFF) && (fb != 23'd0);
    wire a_is_snan = a_is_nan & ~fa[22];
    wire b_is_snan = b_is_nan & ~fb[22];
    wire a_is_zero = (ea == 8'd0) && (fa == 23'd0);
    wire b_is_zero = (eb == 8'd0) && (fb == 23'd0);

    // compare (sign ignored)
    wire a_mag_lt = (ea < eb) || ((ea == eb) && (fa < fb));
    wire a_mag_gt = (ea > eb) || ((ea == eb) && (fa > fb));
    // wire a_mag_eq = (ea == eb) && (fa == fb);

    always @(*) begin
        out       = 32'd0;
        exception = 1'b0;
        if (a_is_nan && b_is_nan) begin
            out       = QNAN;
            exception = a_is_snan | b_is_snan;
        end
        else if (a_is_nan) begin
            out       = b;
            exception = a_is_snan;
        end
        else if (b_is_nan) begin
            out       = a;
            exception = b_is_snan;
        end
        else begin
            if (a_is_zero && b_is_zero) begin
                // max(+0, -0) = +0 ; only (-0, -0) -> -0
                out = (sa & sb) ? 32'h8000_0000 : 32'h0000_0000;
            end
            // --- Different signs: positive > negative ---
            else if (sa ^ sb) begin
                out = sa ? b : a;
            end
            else begin
                // --- Same sign ---
                if (sa) begin
                    // both negative: smaller magnitude is greater (less negative)
                    if (a_mag_lt)       out = a; // |a| < |b| -> a is greater
                    else if (a_mag_gt)  out = b;
                    else                out = a; // equal
                end else begin
                    // both positive: larger magnitude is greater
                    if (a_mag_gt)       out = a;
                    else if (a_mag_lt)  out = b;
                    else                out = a; // equal
                end
            end
        end
    end
endmodule
