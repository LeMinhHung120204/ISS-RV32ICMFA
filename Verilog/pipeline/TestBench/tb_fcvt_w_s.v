`timescale 1ns/1ps
module tb_fcvt_w_s;
    reg clk;
    reg rst_n;
    reg valid_input;
    reg [31:0] a;
    wire valid_output;
    wire signed [31:0] y;

    // Clock 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate DUT
    fcvt_w_s uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(valid_input),
        .a(a),
        .valid_output(valid_output),
        .y(y)
    );

    initial begin
        $dumpfile("tb_fcvt_w_s.vcd");
        $dumpvars(0, tb_fcvt_w_s);

        rst_n = 0;
        valid_input = 0;
        a = 0;
        #20 rst_n = 1;
        #10 valid_input = 1;

        // Single precision floats
        a = 32'h3F800000; // +1.0
        #20 a = 32'hBF800000; // -1.0
        #20 a = 32'h41200000; // +10.0
        #20 a = 32'hC2480000; // -50.0
        #20 a = 32'h7F800000; // +Inf
        #20 a = 32'hFF800000; // -Inf

        #20 valid_input = 0;
        #100 $finish;
    end
endmodule
