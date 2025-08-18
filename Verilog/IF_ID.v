module IF_ID #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] RD, 
    input [ADDR_WIDTH - 1:0] PC,
    output [DATA_WIDTH - 1:0] Instr,
    output [ADDR_WIDTH - 1:0] OldPc
);
    reg [ADDR_WIDTH - 1:0] reg_PC;
    reg [DATA_WIDTH - 1:0] reg_Instr;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_PC      <= 32'd0;
            reg_Instr   <= 32'd0;
        end 
        else begin
            reg_PC      <= PC;
            reg_Instr   <= RD;
        end 
    end 

    assign OldPc    = reg_PC;
    assign RD       = reg_Instr;
endmodule