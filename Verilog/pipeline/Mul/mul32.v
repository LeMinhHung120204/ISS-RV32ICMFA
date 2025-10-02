`timescale 1ns/1ps
module mul32 #(
    parameter DATA_WIDH = 32
)(
    input   clk, rst_n, valid_input,
    input   [1:0] is_unsigned,         
    input   [DATA_WIDH - 1:0] a, b,
    output  valid_output,
    output  [DATA_WIDH - 1:0] R_high, R_low
);
    /*
    00: unsigned x unsigned
    01: signed x signed
    11: signed x unsigned
    */

    localparam num_reg = 12;
    localparam OUTW    = DATA_WIDH*2;

    wire [OUTW-1:0] pp      [0:10];
    // wire [OUTW-1:0] pp_sx   [0:10];
    wire [OUTW-1:0] sum     [0:0];
    wire [OUTW-1:0] carry   [0:0];
    
    wire sign_fill;
    reg [OUTW-1:0]  tmp         [0:num_reg-1];
    reg [3:0]       hold_valid;    

    assign sign_fill = (is_unsigned[0]) ? 1'b0 : b[DATA_WIDH-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1'b1) begin
                tmp[i] <= 64'd0;
            end 
            hold_valid <= 4'd0;
        end
        else begin
            hold_valid  <= {hold_valid[2:0], valid_input};

            tmp[0]      <= pp[0]         + (pp[1] << 3);
            tmp[1]      <= (pp[2] << 6)  + (pp[3] << 9);
            tmp[2]      <= (pp[4] << 12) + (pp[5] << 15);
            tmp[3]      <= (pp[6] << 18) + (pp[7] << 21);
            tmp[4]      <= (pp[8] << 24) + (pp[9] << 27);
            tmp[5]      <= (pp[10] << 30);
    
            tmp[6]      <= tmp[0] + tmp[1];
            tmp[7]      <= tmp[2] + tmp[3];
            tmp[8]      <= tmp[4] + tmp[5];

            tmp[9]      <= sum[0];
            tmp[10]     <= carry[0];

            tmp[11]     <= tmp[9] + tmp[10];
        end 
    end 

    assign R_high       = tmp[11][63:32];
    assign R_low        = tmp[11][31:0]; 
    assign valid_output = hold_valid[3];

    // 11 group 4-bit cho radix-8 Booth:
    wire [3:0] sel0  = {b[2:0],  1'b0};
    wire [3:0] sel1  = b[5:2];
    wire [3:0] sel2  = b[8:5];
    wire [3:0] sel3  = b[11:8];
    wire [3:0] sel4  = b[14:11];
    wire [3:0] sel5  = b[17:14];
    wire [3:0] sel6  = b[20:17];
    wire [3:0] sel7  = b[23:20];
    wire [3:0] sel8  = b[26:23];
    wire [3:0] sel9  = b[29:26];
    wire [3:0] sel10 = {sign_fill, b[31:29]};

    // genvar gi;
    // generate
    //     for (gi = 0; gi < 11; gi = gi + 1) begin : SX
    //         assign pp_sx[gi] = {(is_unsigned) ? 30'd0 : {30{pp[gi][33]}}, pp[gi]};
    //     end
    // endgenerate

    // booth decode 
    booth_decode #(.DATA_WIDH(62)) u_bd0  (.A(a), .is_signed(is_unsigned[1]), .sel(sel0),  .res(pp[0]));
    booth_decode #(.DATA_WIDH(62)) u_bd1  (.A(a), .is_signed(is_unsigned[1]), .sel(sel1),  .res(pp[1]));
    booth_decode #(.DATA_WIDH(62)) u_bd2  (.A(a), .is_signed(is_unsigned[1]), .sel(sel2),  .res(pp[2]));
    booth_decode #(.DATA_WIDH(62)) u_bd3  (.A(a), .is_signed(is_unsigned[1]), .sel(sel3),  .res(pp[3]));
    booth_decode #(.DATA_WIDH(62)) u_bd4  (.A(a), .is_signed(is_unsigned[1]), .sel(sel4),  .res(pp[4]));
    booth_decode #(.DATA_WIDH(62)) u_bd5  (.A(a), .is_signed(is_unsigned[1]), .sel(sel5),  .res(pp[5]));
    booth_decode #(.DATA_WIDH(62)) u_bd6  (.A(a), .is_signed(is_unsigned[1]), .sel(sel6),  .res(pp[6]));
    booth_decode #(.DATA_WIDH(62)) u_bd7  (.A(a), .is_signed(is_unsigned[1]), .sel(sel7),  .res(pp[7]));
    booth_decode #(.DATA_WIDH(62)) u_bd8  (.A(a), .is_signed(is_unsigned[1]), .sel(sel8),  .res(pp[8]));
    booth_decode #(.DATA_WIDH(62)) u_bd9  (.A(a), .is_signed(is_unsigned[1]), .sel(sel9),  .res(pp[9]));
    booth_decode #(.DATA_WIDH(62)) u_bd10 (.A(a), .is_signed(is_unsigned[1]), .sel(sel10), .res(pp[10]));

    csa #(.WIDTH(OUTW)) csa0(.x(tmp[6]),           .y(tmp[7]),        .z(tmp[8]),        .sum(sum[0]), .carry(carry[0]));

endmodule