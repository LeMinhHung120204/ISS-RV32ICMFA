`timescale 1ns/1ps
// from Lee Min Hunz with luv
module ram #(
    parameter DATA_W        = 32
,   parameter ADDR_W        = 8
,   parameter RESET_VALUE   = 32'h0000_0000
,   parameter INIT_FILE_A   = ""
,   parameter INIT_FILE_B   = ""
,   parameter INIT_IDX_A    = 0
,   parameter INIT_IDX_B    = 0
)(
    input               clk 
// ,   input               rst_n
,   input               we
,   input               re
,   input  [ADDR_W-1:0] w_addr
,   input  [ADDR_W-1:0] r_addr
,   input  [DATA_W-1:0] w_data
,   output [DATA_W-1:0] r_data
,   output reg          valid
);
    reg [DATA_W-1:0] mem [0:(1 << ADDR_W) - 1];
    integer i;

    initial begin
        // 1. Khởi tạo giá trị mặc định cho toàn bộ mem
        for (i = 0; i < (1 << ADDR_W); i = i + 1) begin
            mem[i] = RESET_VALUE;
        end

        // 2. Nạp chương trình Core A nếu có file
        if (INIT_FILE_A != "") begin
            $readmemh(INIT_FILE_A, mem, INIT_IDX_A);
        end

        // 3. Nạp chương trình Core B nếu có file
        if (INIT_FILE_B != "") begin
            $readmemh(INIT_FILE_B, mem, INIT_IDX_B);
        end
    end

    reg [DATA_W-1:0] OutMem;

    initial begin
        for (i = 0; i < (1 << ADDR_W); i = i + 1) begin
            mem[i] = RESET_VALUE;
        end
    end

    always @(posedge clk) begin
        if (we) begin
            mem[w_addr] <= w_data; 
        end 
        
        if (re) begin
            OutMem  <= mem[r_addr];
            valid   <= 1'b1;
        end 
        else begin
            valid   <= 1'b0;
        end 
    end

    assign r_data = OutMem;

endmodule