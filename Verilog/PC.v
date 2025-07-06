module PC(
    input clk,
    input reset,
    input pc_src,               // 0: tuần tự, 1: nhảy
    input [31:0] pc_branch,     // địa chỉ nhảy nếu có
    output reg [31:0] pc,       // PC hiện tại
    output [31:0] instrD        // lệnh tại địa chỉ PC
);

    // Giả lập bộ nhớ lệnh (ROM nhỏ)
    reg [31:0] instr_mem [0:255];  // 256 lệnh max

    // Load lệnh vào ROM từ file (nếu cần)
    initial begin
        $readmemh("program.hex", instr_mem);  // hoặc $readmemb
    end

    // Cập nhật PC
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 32'h0000_0000;
        else if (pc_src)
            pc <= pc_branch;
        else
            pc <= pc + 4;
    end

    // Lấy lệnh từ ROM
    assign instrD = instr_mem[pc[9:2]];  // pc / 4 (vì word aligned)

endmodule
