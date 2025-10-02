`timescale 1ns/1ps
module mul24 #(
    parameter DATA_WIDH = 24
)(
    input   clk, rst_n, valid_input,
    input   [1:0] is_unsigned,         
    input   [DATA_WIDH - 1:0] a, b,
    output  valid_output,
    output  [(DATA_WIDH * 2) - 1:0] R
);
    /*
    00: unsigned x unsigned
    01: signed x signed
    11: signed x unsigned
    */

    localparam num_reg = 7;
    localparam OUTW    = DATA_WIDH*2;

    wire [(DATA_WIDH * 2) - 1:0] pp [0:8];
    // wire [OUTW-1:0] pp_sx   [0:8];
    wire [OUTW-1:0] sum     [0:0];
    wire [OUTW-1:0] carry   [0:0];
    
    wire sign_fill;
    reg [OUTW-1:0]  tmp     [0:num_reg-1];
    reg [2:0]       hold_valid;    

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1'b1) begin
                tmp[i] <= {OUTW{1'b0}};
            end 
            hold_valid <= 3'd0;
        end
        else begin
            hold_valid  <= {hold_valid[1:0], valid_input};

            tmp[0]      <= pp[0]         + (pp[1] << 3);
            tmp[1]      <= (pp[2] << 6)  + (pp[3] << 9);
            tmp[2]      <= (pp[4] << 12) + (pp[5] << 15);
            tmp[3]      <= (pp[6] << 18) + (pp[7] << 21) + (pp[8] << 24);
    
            tmp[4]      <= tmp[0] + tmp[1];
            tmp[5]      <= tmp[2] + tmp[3];

            tmp[6]      <= tmp[4] + tmp[5];
        end 
    end 

    assign R            = tmp[6];
    assign valid_output = hold_valid[2];

    // 11 group 4-bit cho radix-8 Booth:
    wire [3:0] sel0 = {b[2:0], 1'b0};
    wire [3:0] sel1 = b[5:2];
    wire [3:0] sel2 = b[8:5];
    wire [3:0] sel3 = b[11:8];
    wire [3:0] sel4 = b[14:11];
    wire [3:0] sel5 = b[17:14];
    wire [3:0] sel6 = b[20:17];
    wire [3:0] sel7 = b[23:20];
    wire [3:0] sel8 = {3'b0, b[23]};

    // booth decode 
    booth_decode #(.DATA_WIDH(46)) u_bd0 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel0), .res(pp[0]));
    booth_decode #(.DATA_WIDH(46)) u_bd1 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel1), .res(pp[1]));
    booth_decode #(.DATA_WIDH(46)) u_bd2 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel2), .res(pp[2]));
    booth_decode #(.DATA_WIDH(46)) u_bd3 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel3), .res(pp[3]));
    booth_decode #(.DATA_WIDH(46)) u_bd4 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel4), .res(pp[4]));
    booth_decode #(.DATA_WIDH(46)) u_bd5 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel5), .res(pp[5]));
    booth_decode #(.DATA_WIDH(46)) u_bd6 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel6), .res(pp[6]));
    booth_decode #(.DATA_WIDH(46)) u_bd7 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel7), .res(pp[7]));
    booth_decode #(.DATA_WIDH(46)) u_bd8 (.A({22'b0, a}), .is_signed(1'b0), .sel(sel8), .res(pp[8]));
    

endmodule