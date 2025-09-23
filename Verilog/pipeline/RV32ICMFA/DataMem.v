`timescale 1ns/1ps
module DataMem #(
    parameter WIDTH_ADDR = 8,
    parameter Data_WIDTH = 32
)(
    input   clk, rst_n, MemWrite,
    input   [Data_WIDTH - 1:0]  addr,
    input   [Data_WIDTH - 1:0]  data_in,
    input   [2:0]               StoreSrc,
    output  [Data_WIDTH - 1:0]  rd
);
    reg [Data_WIDTH - 1:0] mem [0:(1 << WIDTH_ADDR) - 1];
    reg [Data_WIDTH - 1:0] OutMem;

    wire [29:0] word_addr;
    wire [1:0]  mode, offset;
    wire is_unsigned;
    
    assign word_addr    = addr[31:2];
    assign offset       = addr[1:0];
    assign mode         = StoreSrc[1:0];
    assign is_unsigned  = StoreSrc[2];
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for(i = 0 ; i < (1 << WIDTH_ADDR); i = i + 1'b1) begin
                mem[i] <= 32'd0;
            end 
        end
        else begin
            if (MemWrite) begin
                case(mode)
                    2'b00: mem[addr] <= data_in; 
                    2'b01: begin
                        case(offset)
                            2'b00: mem[word_addr][7:0]      <= data_in;
                            2'b01: mem[word_addr][15:8]     <= data_in;
                            2'b10: mem[word_addr][23:16]    <= data_in;
                            2'b11: mem[word_addr][31:24]    <= data_in;
                        endcase
                    end 
                    2'b10: begin
                        case(offset)
                            2'b00: mem[word_addr][15:0]     <= data_in;
                            2'b01: mem[word_addr][31:16]    <= data_in;
                        endcase
                    end 
                endcase
            end
        end 
    end

    always @(*) begin
        case(mode)
            2'b00: OutMem = mem[addr];
            2'b01: begin
                case(offset)
                    2'b00: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][7:0]}    : {{24{mem[addr][7]}}, mem[word_addr][7:0]};
                    2'b01: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][15:8]}   : {{24{mem[addr][15]}}, mem[word_addr][15:8]};
                    2'b10: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][23:16]}  : {{24{mem[addr][23]}}, mem[word_addr][23:16]};
                    2'b11: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][31:24]}  : {{24{mem[addr][31]}}, mem[word_addr][31:24]};
                    default: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][7:0]}  : {{24{mem[addr][7]}}, mem[word_addr][7:0]};
                endcase
            end 
            2'b10: begin
                case(offset)
                    2'b00: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][15:0]}   : {{24{mem[word_addr][15]}}, mem[word_addr][15:0]};
                    2'b01: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][31:16]}  : {{24{mem[word_addr][31]}}, mem[word_addr][31:16]};
                    default: OutMem = (is_unsigned) ? {24'b0, mem[word_addr][15:0]} : {{24{mem[word_addr][15]}}, mem[word_addr][15:0]};
                endcase
            end 
            default: OutMem = mem[addr];
        endcase
    end 
    assign rd = OutMem;

endmodule 