module ID_EX #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] RD1, RD2,
    output [DATA_WIDTH - 1:0] OldRD1, OldRD2
);

    reg [DATA_WIDTH - 1:0] reg_RD1, reg_RD2;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_RD1 <= 32'd0;
            reg_RD2 <= 32'd0;
        end 
        else begin
            reg_RD1 <= RD1;
            reg_RD2 <= RD2;
        end
    end 

    assign OldRD1 = reg_RD1;
    assign OldRD2 = reg_RD2;
endmodule   