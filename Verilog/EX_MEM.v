module EX_MEM #(
    parameter DATA_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] ALUResult,
    output [DATA_WIDTH - 1:0] ALUOut
);
    reg [DATA_WIDTH - 1:0] reg_ALUResult;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_ALUResult <= 32'd0;
        end 
        else begin
            reg_ALUResult <= ALUResult;
        end 
    end 

    assign ALUOut = reg_ALUResult;
endmodule