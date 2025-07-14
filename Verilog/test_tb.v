`timescale 1ps/1ps
`include "test.v"

module test_tb;

    reg a, b;
    wire out;

    // Instantiate the test module
    test uut (
        .a(a),
        .b(b),
        .out(out)
    );

    initial begin
        $dumpfile("wave.vcd");       // tên file vcd muốn ghi
        $dumpvars(0, test_tb);       // 0 là ghi toàn bộ hierarchy từ module test_tb
        // Initialize inputs
        a = 0; b = 0;
        #10; // Wait for 10 time units

        // Test case 1: a = 0, b = 0
        if (out !== 0) $display("Test failed: expected out = 0, got %b", out);

        // Test case 2: a = 0, b = 1
        b = 1; #10;
        if (out !== 0) $display("Test failed: expected out = 0, got %b", out);

        // Test case 3: a = 1, b = 0
        a = 1; b = 0; #10;
        if (out !== 0) $display("Test failed: expected out = 0, got %b", out);

        // Test case 4: a = 1, b = 1
        b = 1; #10;
        if (out !== 1) $display("Test failed: expected out = 1, got %b", out);

        $finish; // End simulation
    end
endmodule