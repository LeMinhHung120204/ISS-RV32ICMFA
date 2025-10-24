`timescale 1ns/1ps
module tb_fmul;
  localparam DW = 32;

  reg               clk;
  reg               rst_n;
  reg               valid_input;
  reg  [DW-1:0]     a, b;
  wire              valid_output;
  wire [DW-1:0]     y;

  integer n_test, n_pass;

  // 200 MHz
  initial clk = 1'b0;
  always #2.5 clk = ~clk;

  // DUT
  fmul #(.WIDTH(DW)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_input(valid_input),
    .a(a),
    .b(b),
    .valid_output(valid_output),
    .y(y)
  );

  // ===== Task tuần tự tuyệt đối =====
  task do_mul;
    input  [DW-1:0] in_a;
    input  [DW-1:0] in_b;
    input           check_en;
    input  [DW-1:0] expected;
    reg    [DW-1:0] got;
    begin
      // 1) Đảm bảo DUT "rảnh": chờ mọi valid_output cũ hạ về 0
      @(posedge clk);
      while (valid_output === 1'b1) @(posedge clk);

      // 2) Setup dữ liệu, giữ ổn định ít nhất 1 chu kỳ trước khi pulse (an toàn)
      a <= in_a;
      b <= in_b;
      @(negedge clk);

      // 3) Pulse valid_input đúng 1 chu kỳ
      valid_input <= 1'b1;
      @(negedge clk);
      valid_input <= 1'b0;

      // 4) Chờ kết quả -> valid_output lên 1
      @(posedge clk);
      while (valid_output !== 1'b1) @(posedge clk);
      got = y;

      n_test = n_test + 1;
      if (check_en) begin
        if (got === expected) begin
          n_pass = n_pass + 1;
          $display("[PASS] a=%h b=%h -> y=%h (expect %h)", in_a, in_b, got, expected);
        end else begin
          $display("[FAIL] a=%h b=%h -> y=%h (expect %h)", in_a, in_b, got, expected);
        end
      end else begin
        $display("[INFO] a=%h b=%h -> y=%h", in_a, in_b, got);
      end

      // 5) Chờ valid_output hạ về 0 (DUT hoàn tất, quay lại get_input)
      @(posedge clk);
      while (valid_output === 1'b1) @(posedge clk);
      // (Không đổi a,b cho tới khi DUT xong hẳn)
    end
  endtask

  initial begin
    valid_input = 0; a = 0; b = 0; n_test = 0; n_pass = 0;

    // Reset
    rst_n = 0; repeat (5) @(posedge clk);
    rst_n = 1; @(posedge clk);

    // --- Vector kiểm thử tuần tự ---
    do_mul(32'h3F800000, 32'h3F800000, 1, 32'h3F800000); // 1.0*1.0=1.0
    do_mul(32'h40000000, 32'h3F000000, 1, 32'h3F800000); // 2.0*0.5=1.0
    do_mul(32'h3FC00000, 32'h40000000, 1, 32'h40400000); // 1.5*2.0=3.0
    do_mul(32'h3F000000, 32'h3F000000, 1, 32'h3E800000); // 0.5*0.5=0.25
    do_mul(32'h00000000, 32'h3F800000, 1, 32'h00000000); // +0*1=+0
    do_mul(32'h80000000, 32'h3F800000, 1, 32'h80000000); // -0*1=-0
    do_mul(32'hC0400000, 32'h40000000, 1, 32'hC0C00000); // -3*2=-6
    do_mul(32'h3F800000, 32'h7F800000, 1, 32'h7F800000); // 1*+Inf=+Inf
    do_mul(32'h7F800000, 32'h00000000, 1, 32'h7FC00000); // +Inf*0=NaN
    do_mul(32'h7FC00000, 32'h3F800000, 1, 32'h7FC00000); // NaN*1=NaN

    // Quan sát subnormal (không check)
    do_mul(32'h00000001, 32'h3F800000, 0, 32'h00000000);
    do_mul(32'h007FFFFF, 32'h40000000, 0, 32'h00000000);

    $display("=========================================");
    $display("FMUL SEQUENTIAL test: PASS %0d / %0d", n_pass, n_test);
    $display("=========================================");
    #20; $finish;
  end
endmodule
