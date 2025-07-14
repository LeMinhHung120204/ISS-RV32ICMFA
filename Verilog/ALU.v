module ALU(
    input  [3:0]  ALUOp,        // Mã điều khiển (chọn phép toán)
    input  [31:0] in1,          // Toán hạng 1
    input  [31:0] in2,          // Toán hạng 2
    output [31:0] result,       // Kết quả ALU
    output [31:0] adder_out,    // Kết quả cộng/trừ (dùng riêng)
    output        cmp_out       // Bit so sánh (dùng cho nhánh)
    output        zero          // Bit chỉ ra kết quả là 0
);
    always @(*) begin
        
    end
endmodule
