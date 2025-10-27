`timescale 1ns/1ps
module mul32 #(
    parameter DATA_WIDH = 32
)(
    input   clk, rst_n, valid_input,
    input   [1:0] is_unsigned,         
    input   [DATA_WIDH - 1:0] a, b,
    output  [DATA_WIDH - 1:0] R_high, R_low,
    output  valid_output, 
    output  reg is_busy
);
    /*
    00: unsigned x unsigned
    01: signed x signed
    11: signed x unsigned
    */

    localparam IDLE = 0, COMPUTE = 1, DONE = 2;
    localparam num_reg = 12;
    localparam OUTW    = DATA_WIDH*2;

    wire [OUTW-1:0] pp      [0:10];
    // wire [OUTW-1:0] pp_sx   [0:10];
    wire [OUTW-1:0] sum     [0:0];
    wire [OUTW-1:0] carry   [0:0];
    wire [61:0]     A_ex;
    
    wire sign_fill;

    reg [1:0]           state;
    reg [OUTW-1:0]      tmp         [0:num_reg-1];
    reg [DATA_WIDH-1:0] reg_rs1, reg_rs2;
    reg [2:0]           compute_count;

    assign sign_fill = (is_unsigned == 2'b01) ? reg_rs2[DATA_WIDH-1] : 1'b0;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1'b1) begin
                tmp[i] <= 64'd0;
            end
            state           <= IDLE;
            reg_rs1         <= 32'd0;
            reg_rs2         <= 32'd0;
            compute_count   <= 3'd0;
            is_busy         <= 1'b0;
        end
        else begin
            case(state)
                IDLE: begin
                    tmp[0]          <= 64'd0;
                    tmp[1]          <= 64'd0;
                    tmp[2]          <= 64'd0;
                    tmp[3]          <= 64'd0;
                    tmp[4]          <= 64'd0;
                    tmp[5]          <= 64'd0;
                    tmp[6]          <= 64'd0;
                    tmp[7]          <= 64'd0;
                    tmp[8]          <= 64'd0;
                    tmp[9]          <= 64'd0;
                    tmp[10]         <= 64'd0;
                    tmp[11]         <= 64'd0;
                    reg_rs1         <= 32'd0;
                    reg_rs2         <= 32'd0;
                    compute_count   <= 3'd0;
                    is_busy         <= 1'b0;
                    if (valid_input) begin
                        reg_rs1 <= a;
                        reg_rs2 <= b;
                        state   <= COMPUTE;
                        is_busy <= 1'b1;
                    end 
                end 
                COMPUTE: begin
                    compute_count   <= compute_count + 1'b1;
                    case(compute_count)
                        3'd0: begin
                            tmp[0]  <= pp[0]         + (pp[1] << 3);
                            tmp[1]  <= (pp[2] << 6)  + (pp[3] << 9);
                            tmp[2]  <= (pp[4] << 12) + (pp[5] << 15);
                            tmp[3]  <= (pp[6] << 18) + (pp[7] << 21);
                            tmp[4]  <= (pp[8] << 24) + (pp[9] << 27);
                            tmp[5]  <= (pp[10] << 30);
                        end
                        3'd1: begin
                            tmp[0]  <= tmp[0] + tmp[1];
                            tmp[1]  <= tmp[2] + tmp[3];
                            tmp[2]  <= tmp[4] + tmp[5];        
                        end 
                        3'd2: begin
                            tmp[0]  <= sum[0];
                            tmp[1]  <= carry[0] << 1;
                        end
                        3'd3: begin
                            tmp[0]  <= tmp[0] + tmp[1];
                            state   <= DONE;
                        end  
                    endcase
                end 
                DONE: begin
                    state           <= IDLE;
                    is_busy         <= 1'b0;
                    compute_count   <= 3'd0;
                end
            endcase

            // tmp[0]      <= pp[0]         + (pp[1] << 3);
            // tmp[1]      <= (pp[2] << 6)  + (pp[3] << 9);
            // tmp[2]      <= (pp[4] << 12) + (pp[5] << 15);
            // tmp[3]      <= (pp[6] << 18) + (pp[7] << 21);
            // tmp[4]      <= (pp[8] << 24) + (pp[9] << 27);
            // tmp[5]      <= (pp[10] << 30);
    
            // tmp[6]      <= tmp[0] + tmp[1];
            // tmp[7]      <= tmp[2] + tmp[3];
            // tmp[8]      <= tmp[4] + tmp[5];

            // tmp[9]      <= sum[0];
            // tmp[10]     <= carry[0] << 1;

            // tmp[11]     <= tmp[9] + tmp[10];
        end 
    end 

    assign R_high       = tmp[0][63:32];
    assign R_low        = tmp[0][31:0];
    assign valid_output = (state == DONE) ? 1'b1 : 1'b0;

    // 11 group 4-bit cho radix-8 Booth:
    wire [3:0] sel0  = {reg_rs2[2:0],  1'b0};
    wire [3:0] sel1  = reg_rs2[5:2];
    wire [3:0] sel2  = reg_rs2[8:5];
    wire [3:0] sel3  = reg_rs2[11:8];
    wire [3:0] sel4  = reg_rs2[14:11];
    wire [3:0] sel5  = reg_rs2[17:14];
    wire [3:0] sel6  = reg_rs2[20:17];
    wire [3:0] sel7  = reg_rs2[23:20];
    wire [3:0] sel8  = reg_rs2[26:23];
    wire [3:0] sel9  = reg_rs2[29:26];
    wire [3:0] sel10 = {sign_fill, reg_rs2[31:29]};

    assign A_ex = (is_unsigned[0]) ? {{30{reg_rs1[31]}}, reg_rs1} : {30'd0, reg_rs1};

    // booth decode 
    booth_decode #(.DATA_WIDH(62)) u_bd0  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel0),  .res(pp[0]));
    booth_decode #(.DATA_WIDH(62)) u_bd1  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel1),  .res(pp[1]));
    booth_decode #(.DATA_WIDH(62)) u_bd2  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel2),  .res(pp[2]));
    booth_decode #(.DATA_WIDH(62)) u_bd3  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel3),  .res(pp[3]));
    booth_decode #(.DATA_WIDH(62)) u_bd4  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel4),  .res(pp[4]));
    booth_decode #(.DATA_WIDH(62)) u_bd5  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel5),  .res(pp[5]));
    booth_decode #(.DATA_WIDH(62)) u_bd6  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel6),  .res(pp[6]));
    booth_decode #(.DATA_WIDH(62)) u_bd7  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel7),  .res(pp[7]));
    booth_decode #(.DATA_WIDH(62)) u_bd8  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel8),  .res(pp[8]));
    booth_decode #(.DATA_WIDH(62)) u_bd9  (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel9),  .res(pp[9]));
    booth_decode #(.DATA_WIDH(62)) u_bd10 (.A(A_ex), .is_signed(is_unsigned[0]), .sel(sel10), .res(pp[10]));

    csa #(.WIDTH(OUTW)) csa0(.x(tmp[0]), .y(tmp[1]), .z(tmp[2]), .sum(sum[0]), .carry(carry[0]));

endmodule