`timescale 1ns/1ps
module tag_mem #(
    parameter NUM_SETS      = 16,
    parameter TAG_W         = 24,
    parameter INDEX_W       = $clog2(NUM_SETS)
)(
    input                   clk, rst_n, 
    input                   tag_we,
    input                   moesi_we,
    input                   valid_we,
    input                   invalid,
    input   [INDEX_W-1:0]   read_index,
    input   [INDEX_W-1:0]   write_index,
    input   [TAG_W-1:0]     din_tag,
    input   [2:0]           moesi_next_state,

    output reg  [TAG_W-1:0] dout_tag,
    output reg              valid,
    output reg  [2:0]       moesi_current_state
);
    localparam STATE_I = 3'd4;

    reg [TAG_W-1:0] tag_mem     [0:NUM_SETS-1];
    reg             valid_array [0:NUM_SETS-1];
    reg [2:0]       state_moesi [0:NUM_SETS-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                tag_mem[i] <= {TAG_W{1'b0}};
            end
            dout_tag <= {TAG_W{1'b0}};
        end 
        else begin
            if (tag_we) begin
                tag_mem[write_index] <= din_tag;
            end 
            dout_tag <= tag_mem[read_index];
        end 
    end 

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for(i = 0; i < NUM_SETS; i = i + 1) begin 
                valid_array[i] <= 1'b0;
            end
        end 
        else begin
            if (valid_we) begin
                valid_array[write_index] <= 1'b1;
            end 
            else if (invalid) begin
                valid_array[write_index] <= 1'b0;
            end 
            valid <= valid_array[read_index];
        end 
    end 
    
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                state_moesi[i] <= STATE_I;
            end
            moesi_current_state <= STATE_I;
        end 
        else begin
            if (moesi_we) begin
                state_moesi[write_index] <= moesi_next_state;
            end
            moesi_current_state <= state_moesi[read_index];
        end
    end

    // assign dout                 = tag_mem[index];
    // assign moesi_current_state  = state_moesi[index];
endmodule