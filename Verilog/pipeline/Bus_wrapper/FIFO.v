    `timescale 1ns / 1ps
    module FIFO #(
        parameter DATA_W = 32,
        parameter DEPTH  = 8,
        parameter ADDR_W = $clog2(DEPTH)
    )(
        input               clk, rst_n,
        input               push,
        input               pop,
        input [DATA_W-1:0]  din,

        output              empty,
        output              full,
        output [DATA_W-1:0] dout
    );
        reg [DATA_W-1:0]    mem [0:DEPTH-1];
        reg [ADDR_W:0]      wptr, rptr;

        integer i;
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                wptr <= 0;
                rptr <= 0;
                for (i = 0; i < DEPTH; i = i + 1) begin
                    mem[i] <= 0;
                end
            end else begin
                if (push && !full) begin
                    mem[wptr] <= din;
                    wptr <= wptr + 1;
                end
                if (pop && !empty) begin
                    dout <= mem[rptr];
                    rptr <= rptr + 1;
                end
            end
        end

        //VD: wptr = 1000 (da quay vong), rptr = 0000 -> Full
        assign full     = (wptr[ADDR_W] != rptr[ADDR_W]) && (wptr[ADDR_W-1:0] == rptr[ADDR_W-1:0]);
        assign empty    = (wptr == rptr);
        assign dout     = mem[rptr];
    endmodule 