module ram #(
    DATA_W = 32,
    ADDR_W = 8
)(
    input clk, rst_n,
    input we,
    input re,
    input [DATA_W-1:0] w_addr,
    input [ADDR_W-1:0] r_addr,
    input [DATA_W-1:0] w_data,
    output [DATA_W-1:0] r_data
);

    reg [DATA_W-1:0] mem [0:(1 << ADDR_W) - 1];
    reg [DATA_W-1:0] OutMem;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for(i = 0 ; i < (1 << ADDR_W); i = i + 1'b1) begin
                mem[i] <= {DATA_W{1'b0}};
            end 
            OutMem <= {DATA_W{1'b0}};
        end
        else begin
            if (we) begin
                mem[w_addr[ADDR_W-1:0]] <= w_data; 
            end 
            if (re) begin
                OutMem <= mem[r_addr];
            end 
            
        end
    end

    assign r_data = OutMem;
endmodule