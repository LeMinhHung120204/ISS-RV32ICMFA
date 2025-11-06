module amo_calc_unit (
    input [4:0]  funct5,
    input [31:0] rs1_data,
    input [31:0] rs2_data,
    output reg [31:0] amo_result
);

always @(*) begin
    case (funct5)
        5'b00001: amo_result = rs2_data;
        5'b00000: amo_result = rs1_data + rs2_data;
        5'b01100: amo_result = rs1_data & rs2_data;
        5'b01000: amo_result = rs1_data | rs2_data;
        5'b00100: amo_result = rs1_data ^ rs2_data;
        5'b10100: amo_result = ($signed(rs1_data) > $signed(rs2_data)) ? rs1_data : rs2_data;
        5'b10000: amo_result = ($signed(rs1_data) < $signed(rs2_data)) ? rs1_data : rs2_data;
        5'b11100: amo_result = (rs1_data > rs2_data) ? rs1_data : rs2_data;
        5'b11000: amo_result = (rs1_data < rs2_data) ? rs1_data : rs2_data;
        default: amo_result = 32'b0;
    endcase
end

endmodule
