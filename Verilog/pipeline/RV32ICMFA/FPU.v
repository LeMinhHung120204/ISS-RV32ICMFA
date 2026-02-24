`timescale 1ns / 1ps

module FPU #(
    parameter WIDTH = 32
)(
    input   clk, rst_n, en
,   input   [4:0] FPUControl 
,   input   [WIDTH-1:0] rs1, rs2, rs3
,   output  [WIDTH-1:0] rd
    // output  done,
,   output stall
);
    wire    [WIDTH-1:0] res_fclass, res_fadd,   res_fcvt_s_w,   res_fcvt_s_wu,  res_fcvt_w_s,   res_fcvt_wu_s, 
                        res_div,    res_feq,    res_fle,        res_flt,        res_fmadd,      res_fmax,   res_fmin,   res_fmul, 
                        res_fsgnj,  res_fsgnjn, res_fsgnjx,     res_fsqrt;
    wire                done_add,   done_fcvt_s_w,              done_fcvt_s_wu, done_fcvt_w_s,  done_fcvt_wu_s,         done_fdiv, 
                        done_fmadd, done_fmul,  done_fsqrt;
    
    reg [8:0]       valid_input;
    reg [WIDTH-1:0] in1, in2, in3, oRes;
    reg valid_output, reg_stall;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_stall <= 1'b0;
        end 
        else begin
            if (en) begin
                reg_stall <= 1'b1;
                if (valid_output) begin
                    reg_stall <= 1'b0;
                end
            end 
        end
    end 

    assign stall = (reg_stall | en) & (~valid_output);

    always @(*) begin
        case({FPUControl, en})
            6'b0_0000_1: begin     // add
                valid_input     = 9'b0_0000_0001;
                in1             = rs1;
                in2             = rs2;
                in3             = 32'd0;
                oRes            = res_fadd;
                valid_output    = done_add;
            end 

            6'b0_0001_1: begin     // sub
                valid_input     = 9'b0_0000_0001;
                in1             = rs1;
                in2             = {~rs2[31], rs2[30:0]};
                in3             = 32'd0;
                oRes            = res_fadd;
                valid_output    = done_add;
            end 

            6'b0_0010_1: begin     // fclass
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fclass;
                valid_output    = 1'b1;
            end 

            6'b0_0011_1: begin     // fcvt.s.w
                valid_input     = 9'b0_0000_0010;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fcvt_s_w;
                valid_output    = done_fcvt_s_w;
            end 

            6'b0_0100_1: begin     // fcvt.s.wu
                valid_input     = 9'b0_0000_0100;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fcvt_s_wu;
                valid_output    = done_fcvt_s_wu;
            end 

            6'b0_0101_1: begin     // fcvt.w.s
                valid_input     = 9'b0_0000_1000;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fcvt_w_s;
                valid_output    = done_fcvt_w_s;
            end 

            6'b0_0110_1: begin     // fcvt.wu.s
                valid_input     = 9'b0_0001_0000;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fcvt_wu_s;
                valid_output    = done_fcvt_wu_s;
            end 

            6'b0_0111_1: begin     // fdiv
                valid_input     = 9'b0_0010_0000;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_div;
                valid_output    = done_fdiv;
            end

            6'b0_1000_1: begin     // feq
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_feq;
                valid_output    = 1'b1;
            end 

            6'b0_1001_1: begin     // fle
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fle;
                valid_output    = 1'b1;
            end 

            6'b0_1010_1: begin    // flt
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_flt;
                valid_output    = 1'b1;
            end 

            6'b0_1011_1: begin    // fmadd
                valid_input     = 9'b0_0100_0000;
                in1             = rs1;
                in2             = rs2;
                in3             = rs3;
                oRes            = res_fmadd;
                valid_output    = done_fmadd;
            end 

            6'b0_1100_1: begin    // fmsub
                valid_input     = 9'b0_0100_0000;
                in1             = rs1;
                in2             = rs2;
                in3             = {~rs3[31], rs3[30:0]};
                oRes            = res_fmadd;
                valid_output    = done_fmadd;
            end 

            6'b0_1101_1: begin    // fnmadd
                valid_input     = 9'b0_0100_0000;
                in1             = {~rs1[31], rs1[30:0]};
                in2             = rs2;
                in3             = rs3;
                oRes            = res_fmadd;
                valid_output    = done_fmadd;
            end 

            6'b0_1110_1: begin    // fnmsub
                valid_input     = 9'b0_0100_0000;
                in1             = {~rs1[31], rs1[30:0]};
                in2             = rs2;
                in3             = {~rs3[31], rs3[30:0]};
                oRes            = res_fmadd;
                valid_output    = done_fmadd;
            end 

            6'b0_1111_1: begin    // fmax
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fmax;
                valid_output    = 1'b1;
            end 

            6'b1_0000_1: begin    // fmin
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fmin;
                valid_output    = 1'b1;
            end 

            6'b1_0001_1: begin    // fmul
                valid_input     = 9'b0_1000_0000;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fmul;
                valid_output    = done_fmul;
            end 

            6'b1_0010_1: begin    // fsgnj
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fsgnj;
                valid_output    = 1'b1;
            end 

            6'b1_0011_1: begin    // fsgnjn
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fsgnjn;
                valid_output    = 1'b1;
            end 

            6'b1_0100_1: begin    // fsgnjx
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fsgnjx;
                valid_output    = 1'b1;
            end

            6'b1_0101_1: begin    // fsqrt
                valid_input     = 9'b1_0000_0000;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = res_fsqrt;
                valid_output    = done_fsqrt;
            end
            
            6'b1_0110_1: begin    // fmv.x.w / fmv.w.x
                valid_input     = 9'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                oRes            = rs1;
                valid_output    = 1'b1;
            end 

            default: begin
                oRes            = 32'd0;
                in1             = 32'd0;
                in2             = 32'd0;
                in3             = 32'd0;
                valid_input     = 9'd0;
                valid_output    = 1'b0;
            end 
        endcase
    end

    assign rd   = (valid_output) ? oRes : 32'd0;
    // assign done = valid_output;

    fadd fadd_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[0]),
        .a(in1),
        .b(in2),
        .valid_output(done_add),
        .y(res_fadd)
    );

    fclass fclass_inst(
        .a(rs1),
        .out(res_fclass)
    );

    fcvt_s_w fcvt_s_w_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[1]),
        .a(rs1),
        .valid_output(done_fcvt_s_w),
        .y(res_fcvt_s_w)
    );

    fcvt_s_wu fcvt_s_wu_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[2]),
        .a(rs1),
        .valid_output(done_fcvt_s_wu),
        .y(res_fcvt_s_wu)
    );  

    fcvt_w_s fcvt_w_s_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[3]),
        .a(rs1),
        .valid_output(done_fcvt_w_s),
        .y(res_fcvt_w_s)
    );   

    fcvt_wu_s fcvt_wu_s_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[4]),
        .a(rs1),
        .valid_output(done_fcvt_wu_s),
        .y(res_fcvt_wu_s)
    );

    fdiv fdiv_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[5]),
        .a(rs1),
        .b(rs2),
        .valid_output(done_fdiv),
        .y(res_div)
    );

    feq feq_inst(
        .a(rs1),
        .b(rs2),
        .out(res_feq),
        .exception()
    );

    fle fle_inst(
        .a(rs1),
        .b(rs2),
        .out(res_fle),
        .exception()
    );

    flt flt_inst(
        .a(rs1),
        .b(rs2),
        .out(res_flt),
        .exception()
    );

    fmadd fmadd_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[6]),
        .rs1(in1),
        .rs2(in2),
        .rs3(in3),
        .rd(res_fmadd),
        .valid_output(done_fmadd)
    );

    fmax max_inst(
        .a(rs1),
        .b(rs2),
        .out(res_fmax),
        .exception()
    );

    fmin min_inst(
        .a(rs1),
        .b(rs2),
        .out(res_fmin),
        .exception()
    );

    fmul fmul_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[7]),
        .a(rs1),
        .b(rs2),
        .y(res_fmul),
        .valid_output(done_fmul)
    );

    fsgnj fsgnj_inst(
        .rs1(rs1),
        .rs2(rs2),
        .rd(res_fsgnj)
    );

    fsgnjn fsgnjn_inst(
        .rs1(rs1),
        .rs2(rs2),
        .rd(res_fsgnjn)
    );

    fsgnjx fsgnjx_inst(
        .rs1(rs1),
        .rs2(rs2),
        .rd(res_fsgnjx)
    );

    fsqrt2 fsqrt_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input[8]),
        .radicand(rs1),
        .y(res_fsqrt),
        .valid_output(done_fsqrt)
    );
endmodule