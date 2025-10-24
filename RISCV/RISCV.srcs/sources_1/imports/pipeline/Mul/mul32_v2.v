`timescale 1ns/1ps
module mul32_v2 #(
    parameter DATA_WIDH = 32
)(
    input   clk, rst_n,
    input   is_unsigned,         
    input   [DATA_WIDH - 1:0] a, b,
    output  [(DATA_WIDH * 2) - 1:0] R
);
    localparam num_reg = 18;
    localparam OUTW    = DATA_WIDH*2;

    wire [DATA_WIDH+1:0] pp [0:10];
    wire [OUTW-1:0] pp_sx   [0:10];
    wire [OUTW-1:0] tmp_sum [0:2];
    wire [OUTW-1:0] sum     [0:6];
    wire [OUTW-1:0] carry   [0:6];
    
    wire sign_fill;
    wire [2:0] cout;

    reg  [OUTW-1:0] tmp [0:num_reg-1];

    assign sign_fill = is_unsigned ? 1'b0 : b[DATA_WIDH-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1'b1) begin
                tmp[i] <= 64'd0;
            end 
        end
        else begin
            // state 1
            tmp[0]  <= sum[0];
            tmp[1]  <= sum[1];
            tmp[2]  <= sum[2];
            tmp[3]  <= carry[0];
            tmp[4]  <= carry[1];
            tmp[5]  <= carry[2];
            tmp[6]  <= tmp_sum[0];

            // state 2
            tmp[7]  <= sum[3];
            tmp[8]  <= carry[3];            
            tmp[9]  <= sum[4];
            tmp[10] <= carry[4];
            tmp[11] <= tmp[6];

            // state 3
            tmp[12] <= sum[5];
            tmp[13] <= carry[5];
            tmp[14] <= tmp_sum[1];

            // state 4
            tmp[15] <= sum[6];
            tmp[16] <= carry[6];

            // state 5
            tmp[17] <= tmp_sum[2];
        end 
    end 

    assign R = tmp[17];

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

    genvar gi;
    generate
        for (gi = 0; gi < 11; gi = gi + 1) begin : SX
            assign pp_sx[gi] = {(is_unsigned) ? 30'd0 : {30{pp[gi][33]}}, pp[gi]};
        end
    endgenerate

    // booth decode 
    booth_decode u_bd0  (.A(a), .sel(sel0),  .res(pp[0]));
    booth_decode u_bd1  (.A(a), .sel(sel1),  .res(pp[1]));
    booth_decode u_bd2  (.A(a), .sel(sel2),  .res(pp[2]));
    booth_decode u_bd3  (.A(a), .sel(sel3),  .res(pp[3]));
    booth_decode u_bd4  (.A(a), .sel(sel4),  .res(pp[4]));
    booth_decode u_bd5  (.A(a), .sel(sel5),  .res(pp[5]));
    booth_decode u_bd6  (.A(a), .sel(sel6),  .res(pp[6]));
    booth_decode u_bd7  (.A(a), .sel(sel7),  .res(pp[7]));
    booth_decode u_bd8  (.A(a), .sel(sel8),  .res(pp[8]));
    booth_decode u_bd9  (.A(a), .sel(sel9),  .res(pp[9]));
    booth_decode u_bd10 (.A(a), .sel(sel10), .res(pp[10]));

    // csa
    csa #(.WIDTH(OUTW)) csa0(.x(pp_sx[0]),          .y(pp_sx[1] << 3),  .z(pp_sx[2] << 6),  .sum(sum[0]), .carry(carry[0]));
    csa #(.WIDTH(OUTW)) csa1(.x(pp_sx[3] << 9),     .y(pp_sx[4] << 12), .z(pp_sx[5] << 15), .sum(sum[1]), .carry(carry[1]));
    csa #(.WIDTH(OUTW)) csa2(.x(pp_sx[6] << 18),    .y(pp_sx[7] << 21), .z(pp_sx[8] << 24), .sum(sum[2]), .carry(carry[2]));
    csa #(.WIDTH(OUTW)) csa3(.x(tmp[0]),            .y(tmp[1]),         .z(tmp[2]),         .sum(sum[3]), .carry(carry[3]));
    csa #(.WIDTH(OUTW)) csa4(.x(tmp[3]),            .y(tmp[4]),         .z(tmp[5]),         .sum(sum[4]), .carry(carry[4]));
    csa #(.WIDTH(OUTW)) csa5(.x(tmp[7]),            .y(tmp[8]),         .z(tmp[9]),         .sum(sum[5]), .carry(carry[5]));
    csa #(.WIDTH(OUTW)) csa6(.x(tmp[12]),           .y(tmp[13]),        .z(tmp[14]),        .sum(sum[6]), .carry(carry[6]));

    // cla
    cla_64b cla_ins0(.a(pp_sx[9] << 27),    .b(pp_sx[10] << 30),    .cin(1'b0), .sum(tmp_sum[0]), .cout(cout[0]));
    cla_64b cla_ins1(.a(tmp[10]),           .b(tmp[11]),            .cin(1'b0), .sum(tmp_sum[1]), .cout(cout[1]));
    cla_64b cla_ins2(.a(tmp[15]),           .b(tmp[16]),            .cin(1'b0), .sum(tmp_sum[2]), .cout(cout[2]));

endmodule