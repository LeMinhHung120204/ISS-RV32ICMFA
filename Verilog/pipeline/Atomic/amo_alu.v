module amo_alu #(
    parameter DATA_WIDTH = 32
) (
    input       [DATA_WIDTH-1:0]    i_data_from_mem
,   input       [DATA_WIDTH-1:0]    i_data_from_core
,   input       [3:0]               i_amo_op
,   output  reg [DATA_WIDTH-1:0]    o_amo_alu_result 
);

    always @(*) begin
        case (i_amo_op)
            4'b0000: o_amo_alu_result = i_data_from_core;                   //AMOSWAP
            4'b0001: o_amo_alu_result = i_data_from_mem + i_data_from_core; // AMOADD
            4'b0010: o_amo_alu_result = i_data_from_mem & i_data_from_core; // AMOAND
            4'b0011: o_amo_alu_result = i_data_from_mem | i_data_from_core; // AMOOR
            4'b0100: o_amo_alu_result = i_data_from_mem ^ i_data_from_core; // AMOXOR
            
            // AMOMAX
            4'b0101: o_amo_alu_result = ( $signed(i_data_from_mem)  > $signed(i_data_from_core) ) ? i_data_from_mem : i_data_from_core; 

            // AMOMIN
            4'b0110: o_amo_alu_result = ( $signed(i_data_from_mem)  < $signed(i_data_from_core) ) ? i_data_from_mem : i_data_from_core; 
            default: o_amo_alu_result = {DATA_WIDTH{1'b0}};
        endcase
    end
endmodule