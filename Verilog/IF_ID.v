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
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            instrD    <= 32'd0;       // Reset instruction to 0
            PCD      <= 32'd0;       // Reset PC to 0
            PCPlus4D <= 32'd0;       // Reset PC + 4 to 0
            TakenD   <= 1'b0;        // Reset Taken signal
        end else if (FlushD) begin
            instrD   <= 32'd0;       // Clear instruction on flush
            PCD      <= 32'd0;       // Clear PC on flush
            PCPlus4D <= 32'd0;       // Clear PC + 4 on flush
            TakenD   <= 1'b0;        // Clear Taken signal on flush
        end else if (StallD) begin
            instrD   <= instrD;      // Keep current instruction on stall
            PCD      <= PCD;         // Keep current PC on stall
            PCPlus4D <= PCPlus4D;    // Keep current PC + 4 on stall
            TakenD   <= TakenD;      // Keep current Taken signal on stall
        end else begin
            instrD   <= instruction; // Load new instruction
            PCD      <= PCF;         // Load new PC from Fetch stage
            PCPlus4D <= PCPlus4F;    // Load new PC + 4 from Fetch stage
            TakenD   <= TakenF;      // Load new Taken signal from Fetch stage
        end
    end
endmodule