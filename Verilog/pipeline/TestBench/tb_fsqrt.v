`timescale 1ns/1ps
module tb_fsqrt;
  localparam DW = 32;

  // clock/reset & DUT I/O
  reg               clk;
  reg               rst_n;
  reg               enable;
//  reg               valid_input;
  reg  [DW-1:0]     radicand;
  wire              valid_output;
  wire [DW-1:0]     y;
  reg [9:0]         count_clock;

  integer n_test, n_pass;

  // 5ns period (200 MHz)
  initial clk = 1'b0;
  always #2.5 clk = ~clk;
  
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        count_clock <= 0;
    end 
    else begin
        count_clock <= count_clock + 1'b1;
    end   
  end

  // =========================
  // DUT
  // =========================
//  fsqrt2 #(.WIDTH(DW)) dut (
//    .clk(clk),
//    .rst_n(rst_n),
//    .valid_input(valid_input),
//    .radicand(radicand),
//    .valid_output(valid_output),
//    .y(y)
//  );

 fsqrt dut (
    .clk(clk),
    .rst(rst_n),
    .enable(enable),
    .a(radicand),
    .complete(complete),
    .y(y)
  );

  initial begin
    clk = 0;
    rst_n = 0;
//    valid_input = 0;
    radicand = 0;
    
    #10;
    rst_n = 1'b1;
    enable = 1'b1;
//    valid_input = 1;
    radicand = 32'h40800000;
    
    #5;
//    valid_input = 0;
    
    #100;
    $finish;
  end 
  
endmodule
