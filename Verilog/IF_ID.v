module IF_ID (
    input             clk,
    input             rst,
    input             StallD,       // Tín hiệu dừng pipeline do data hazard
    input             FlushD,       // Khi FlushD = 1, pipeline sẽ xoá sạch lệnh hiện tại, tránh thực thi sai.
    input             TakenF,       // Báo rằng branch đã được lấy ở tầng Fetch (dự đoán nhảy)
    input      [31:0] instruction,  // Instruction fetched from memory
    input      [31:0] PCF,          // địa chỉ PC tại Fetch stage
    input      [31:0] PCPlus4F,     // PC + 4 tại Fetch stage
    output reg        TakenD,       // Taken signal for decode stage
    output reg [31:0] instrD,       // Instruction to decode stage
    output reg [31:0] PCD,          // Program Counter at decode stage
    output reg [31:0] PCPlus4D      // PC + 4 at decode stage
);
endmodule