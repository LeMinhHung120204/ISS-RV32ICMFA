`timescale 1ns/1ps
module tb_feq;
  // Clock & reset
  reg clk = 0;
  reg rst_n = 0;

  // Input / Output
  reg  [31:0] a, b;
  wire [31:0] y;

  // Sinh clock 100 MHz (chu kỳ 10ns)
  always #5 clk = ~clk;

  // DUT
  feq dut (
    .a(a),
    .b(b),
    .y(y)
  );

  // Hàm check đơn giản
  task check;
    input [31:0] aa, bb;
    input expected;
    input [127:0] name;
  begin
    a = aa; b = bb;
    @(posedge clk);  // chờ cạnh clock để ổn định
    #1;
    if (y[0] === expected)
      $display("[PASS] %-15s  a=%h  b=%h  -> y[0]=%0d", name, aa, bb, y[0]);
    else
      $display("[FAIL] %-15s  a=%h  b=%h  -> y[0]=%0d (expected %0d)",
               name, aa, bb, y[0], expected);
  end
  endtask

  // Một số hằng số float
  localparam [31:0] PZERO = 32'h0000_0000; // +0.0
  localparam [31:0] NZERO = 32'h8000_0000; // -0.0
  localparam [31:0] PONE  = 32'h3F80_0000; // 1.0
  localparam [31:0] PTWO  = 32'h4000_0000; // 2.0
  localparam [31:0] QNAN  = 32'h7FC0_0000; // NaN

  initial begin
    // Reset giữ 3 chu kỳ
    repeat(3) @(posedge clk);
    rst_n = 1;

    // Các ca kiểm thử
    check(PZERO, NZERO, 1, "+0 == -0");
    check(PONE,  PONE,  1, "1.0 == 1.0");
    check(PONE,  PTWO,  0, "1.0 == 2.0");
    check(QNAN,  PONE,  0, "NaN == 1.0");

    #20 $finish;
  end
endmodule
