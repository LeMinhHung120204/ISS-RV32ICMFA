`timescale 1ns/1ps
module DataMem #(
    parameter WIDTH_ADDR = 8,
    parameter Data_WIDTH = 32
)(
    input                       clk, rst_n, 
    input                       MemWrite,
    input   [Data_WIDTH - 1:0]  addr,
    input   [Data_WIDTH - 1:0]  data_in,
    input   [2:0]               StoreSrc,
    output  [Data_WIDTH - 1:0]  rd
);
    reg [Data_WIDTH - 1:0] mem [0:(1 << WIDTH_ADDR) - 1];
    reg [Data_WIDTH - 1:0] OutMem;

    // wire [29:0] word_addr;
    // wire [1:0]  mode, offset;
    // wire is_unsigned;

    // assign word_addr    = addr[31:2];
    // assign offset       = addr[1:0];
    // assign mode         = StoreSrc[1:0];
    // assign is_unsigned  = StoreSrc[2];

    wire [WIDTH_ADDR-1:0] word_idx;
    wire [1:0]            mode;
    wire [1:0]            offset;
    wire                  is_unsigned;

    assign word_idx    = addr[WIDTH_ADDR+1 : 2]; 
    assign offset      = addr[1:0];
    assign mode        = StoreSrc[1:0]; // 00: Word, 01: Byte, 10: Half
    assign is_unsigned = StoreSrc[2];
    
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
                // --- Store Word ---
                2'b00: mem[word_idx] <= data_in; 
                
                // --- Store Byte ---
                2'b01: begin
                    case(offset)
                        2'b00: mem[word_idx][7:0]   <= data_in[7:0];
                        2'b01: mem[word_idx][15:8]  <= data_in[7:0];
                        2'b10: mem[word_idx][23:16] <= data_in[7:0];
                        2'b11: mem[word_idx][31:24] <= data_in[7:0];
                    endcase
                end 
                
                // --- Store Half ---
                2'b10: begin
                    if(offset[1] == 1'b0)
                        mem[word_idx][15:0]  <= data_in[15:0];
                    else
                        mem[word_idx][31:16] <= data_in[15:0];
                end 
                endcase
            end
        end 
    end

    reg [7:0]  b_val;
    reg [15:0] h_val;
    always @(*) begin
        case(mode)
            // --- Load Word ---
            2'b00: OutMem = mem[word_idx];

            // --- Load Byte ---
            2'b01: begin
                case(offset)
                    2'b00: b_val = mem[word_idx][7:0];
                    2'b01: b_val = mem[word_idx][15:8];
                    2'b10: b_val = mem[word_idx][23:16];
                    2'b11: b_val = mem[word_idx][31:24];
                endcase
                OutMem = is_unsigned ? {24'd0, b_val} : {{24{b_val[7]}}, b_val};
            end 

            // --- Load Half ---
            2'b10: begin
                if(offset[1] == 1'b0)
                    h_val = mem[word_idx][15:0];
                else
                    h_val = mem[word_idx][31:16];
                
                OutMem = is_unsigned ? {16'd0, h_val} : {{16{h_val[15]}}, h_val};
            end
            
            default: OutMem = mem[word_idx];
        endcase
    end 
    assign rd = OutMem;

endmodule 