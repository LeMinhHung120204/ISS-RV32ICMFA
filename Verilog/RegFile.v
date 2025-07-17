module RegFile(
    input clk,
    input rst, 
    input we,
    input [4:0] rs1, rs2, // read address
    input [4:0] rd,       // write address
    input [31:0] wd,            // write data
    output reg [31:0] rd1, rd2 // read data
);
    reg [31:0] register [31:0];
    always @(*) begin
        rd1 = (rd != 5'b0 && rd == rs1 && we) ? wd : register[rs1];
        rd2 = (rd != 5'b0 && rd == rs2 && we) ? wd : register[rs2];
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            register[0] <= 32'd0;
            register[1] <= 32'd0;
            register[2] <= 32'd448;
            register[3] <= 32'd0;
            register[4] <= 32'd0;
            register[5] <= 32'd0;
            register[6] <= 32'd0;
            register[7] <= 32'd0;
            register[8] <= 32'd0;
            register[9] <= 32'd0;
            register[10] <= 32'd0;
            register[11] <= 32'd0;
            register[12] <= 32'd0;
            register[13] <= 32'd0;
            register[14] <= 32'd0;
            register[15] <= 32'd0;
            register[16] <= 32'd0;
            register[17] <= 32'd0;
            register[18] <= 32'd0;
            register[19] <= 32'd0;
            register[20] <= 32'd0;
            register[21] <= 32'd0;
            register[22] <= 32'd0;
            register[23] <= 32'd0;
            register[24] <= 32'd0;
            register[25] <= 32'd0;
            register[26] <= 32'd0;
            register[27] <= 32'd0;
            register[28] <= 32'd0;
            register[29] <= 32'd0;
            register[30] <= 32'd0;
            register[31] <= 32'd0; 
        end else if (we && rd != 5'b00000) begin
             register[rd] <= wd; 
        end
    end 
endmodule 