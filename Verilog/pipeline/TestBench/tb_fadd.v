`timescale 1ns/1ps
// optional: uncomment nếu bạn dùng Vivado nghiêm ngặt v�? nettype
// `default_nettype none

module tb_fadd;
  localparam DW = 32;

  reg                   clk;
  reg                   rst_n;
  reg                   valid_input;
  reg  [DW-1:0]         a, b;
  reg  [15:0]           count_clock;
  integer               start_cycle;

  wire [DW-1:0]         y;
  wire                  valid_output;

  // 200 MHz clock (T = 5 ns)
  initial clk = 1'b0;
  always #2.5 clk = ~clk;

  // free-running cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) count_clock <= 16'd0;
    else        count_clock <= count_clock + 16'd1;
  end

  // DUT
  fadd dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .valid_input  (valid_input),
    .a            (a),
    .b            (b),
    .y            (y),
    .valid_output (valid_output)
  );

  // --- Task: phát 1 phép cộng và ch�? done ---
  task do_add;
    input [DW-1:0] A;
    input [DW-1:0] B;
    integer to_cnt;
    begin
      // phát input trong 1 chu kỳ
      @(posedge clk);
      a <= A;
      b <= B;
      valid_input <= 1'b1;
      start_cycle = count_clock;

      @(posedge clk);
      valid_input <= 1'b0;

      // ch�? valid_output lên 1, có timeout bảo vệ
      to_cnt = 0;
      while (valid_output !== 1'b1) begin
        @(posedge clk);
        to_cnt = to_cnt + 1;
        if (to_cnt > 10000) begin
          $display("[%0t] ERROR: Timeout waiting for valid_output", $time);
          $fatal(1);
        end
      end

      // in kết quả
      $display("[%0t] cycles=%0d  A=%h  B=%h  Y=%h",
               $time, count_clock - start_cycle, A, B, y);
      // Nếu simulator hỗ trợ SystemVerilog, có thể xem dạng thực:
      // $display("A=%f  B=%f  Y=%f", $bitstoshortreal(A), $bitstoshortreal(B), $bitstoshortreal(y));
    end
  endtask

  // --- Monitor: in mỗi khi valid_output lên 1 ---
  always @(posedge clk) begin
    if (valid_output) begin
      $display("[%0t] OUT valid: y=%h", $time, y);
      // $display("Y(real)=%f", $bitstoshortreal(y));
    end
  end

  // --- Test sequence ---
  initial begin
    // reset
    clk          = 1'b0;
    rst_n        = 1'b0;
    valid_input  = 1'b0;
    a            = 32'd0;
    b            = 32'd0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // 1) 1.5f + 2.25f
    do_add(32'h3FC00000, 32'h40100000);
    // 2) -3.75f + 1.25f
    do_add(32'hC0700000, 32'h3FA00000);
    // 3) 0 + NaN
    do_add(32'h00000000, 32'h7FC00001);
    
    do_add(32'h40400000, 32'h40400000); 
    valid_input <= 1'b0;

    // doi them cho outputs cuoi cung
    repeat (50) @(posedge clk);

    $finish;
  end

  // --- Timeout guard tổng để tránh treo toàn test ---
  initial begin : TIMEOUT
    #10000; // 50 us
    $fatal(1, "TIMEOUT: No completion from DUT (global).");
  end

endmodule
