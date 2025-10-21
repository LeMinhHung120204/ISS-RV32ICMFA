`timescale 1ns/1ps

module tb_fmadd;

    reg clk;
    reg rst_n;

    reg         valid_input;
    reg  [31:0] rs1, rs2, rs3;
    wire [31:0] rd;
    wire        valid_output;

    localparam [31:0] FP_POS_ZERO  = 32'h00000000;
    localparam [31:0] FP_NEG_ZERO  = 32'h80000000;
    localparam [31:0] FP_ONE       = 32'h3F800000; // 1.0
    localparam [31:0] FP_TWO       = 32'h40000000; // 2.0
    localparam [31:0] FP_THREE     = 32'h40400000; // 3.0
    localparam [31:0] FP_FIVE      = 32'h40A00000; // 5.0
    localparam [31:0] FP_SIX       = 32'h40C00000; // 6.0
    localparam [31:0] FP_EIGHT     = 32'h41000000; // 8.0
    localparam [31:0] FP_FOUR      = 32'h40800000; // 4.0
    localparam [31:0] FP_ONEP5     = 32'h3FC00000; // 1.5
    localparam [31:0] FP_NEG_2P5   = 32'hC0200000; // -2.5
    localparam [31:0] FP_NEG_NINE  = 32'hC1100000; // -9.0
    localparam [31:0] FP_INF       = 32'h7F800000; // +Inf
    localparam [31:0] FP_QNAN      = 32'h7FC00001; // quiet NaN mẫu

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    fmadd #(.WIDTH(32)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input),
        .rs1(rs1),
        .rs2(rs2),
        .rs3(rs3),
        .rd(rd),
        .valid_output(valid_output)
    );

    initial begin
        rst_n   = 0;
        rs1     = 0;
        rs2     = 0;
        rs3     = 0;
        valid_input = 0;

        #10; 
        rst_n   = 1;
        valid_input = 1;
        rs1     = FP_ONEP5;
        rs2     = FP_TWO;
        rs3     = FP_THREE;
        #10; 
        valid_input = 0;

        #500;
        $finish;
    end 

    initial begin
        #1000;
        $finish;
    end
endmodule
