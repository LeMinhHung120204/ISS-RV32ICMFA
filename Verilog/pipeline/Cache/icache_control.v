`timescale 1ns/1ps
module icache_control #(
    parameter DATA_W = 32
)(
    input       clk, rst_n, hit, Mem_Ready,
    output reg  data_we, tag_we, Mem_Valid
);
    localparam COMPARE_TAG = 0, ALLOCATE = 1;
    reg state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= COMPARE_TAG;
        end 
        else begin
            state <= next_state;
        end 
    end 

    always @(*) begin
        case(state)
            COMPARE_TAG: begin
                next_state = (~hit) ? COMPARE_TAG : ALLOCATE;
            end 
            ALLOCATE: begin
                if (Mem_Ready) begin
                    tag_we      = 1'b1;
                    data_we     = 1'b1;
                    Mem_Valid   = 1'b1;
                end 
            end 
            default: begin
                next_state  = COMPARE_TAG;
                tag_we      = 1'b0;
                data_we     = 1'b0;
                Mem_Valid   = 1'b0;
            end 
        endcase
    end 
endmodule