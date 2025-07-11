module PC(
    input clk,
    input reset,
    input pc_src,               // 0: tuần tự, 1: nhảy
    input [31:0] pc_branch,     // địa chỉ nhảy nếu có
    output reg [31:0] pc        // PC hiện tại
);
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            pc <= 32'h00000000; // Reset PC về 0
        end else begin
            if (pc_src) begin
                pc <= pc_branch; // Nhảy đến địa chỉ mới
            end else begin
                pc <= pc + 4; // Tăng PC theo tuần tự
            end
        end
    end
endmodule
