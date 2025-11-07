`timescale 1ns/1ps
module data_mem #(
    parameter DATA_W            = 32,
    parameter INDEX_WIDTH       = 4,
    parameter CACHE_DATA_WIDTH  = 512,
    parameter NUM_CACHE_LINES   = 16
)(
    input                           clk, rst_n, we,
    input   [INDEX_WIDTH-1:0]       index,
    input   [DATA_W-1:0]            din,
    input   [1:0]                   word_off,
    // input   [3:0]                       write_wstrb,
    // output reg [CACHE_DATA_WIDTH-1:0]   dout
    output  [CACHE_DATA_WIDTH-1:0]  dout
);

    reg [CACHE_DATA_WIDTH-1:0] data_mem [0:NUM_CACHE_LINES-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_CACHE_LINES; i = i + 1) begin
                data_mem[i] <= {DATA_W{1'b0}};
            end
        end 
        else begin
            if (we) begin
                case(word_off)
                    2'b00: begin
                        data_mem[index][31:0]   <= din; 
                    end 
                    2'b01: begin
                        data_mem[index][63:32]  <= din; 
                    end 
                    2'b10: begin
                        data_mem[index][95:64]  <= din; 
                    end 
                    2'b11: begin
                        data_mem[index][127:96] <= din; 
                    end  
                endcase
            end 
            // dout <= data_mem[index];
        end
    end

    assign dout = cache_data_mem[index];
endmodule