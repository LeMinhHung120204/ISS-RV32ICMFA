module PC @(
    parameter WIDTH = 32;
)(
    input clk, rst_n,
    input [WIDTH - 1:0] PCNext,
    output reg [WIDTH - 1:0] PC
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            PC <= 32'd0;
        end 
        else begin
            PC <= PCnext;
        end 
    end
endmodule
