`timescale 1ns/1ps

module tb_plru;
    localparam N_WAYS       = 4;
    localparam N_LINES      = 16;
    localparam N_WAYS_W     = $clog2(N_WAYS);
    localparam N_LINES_W    = $clog2(N_LINES);

    reg                 clk, rst_n, we;
    reg [N_WAYS-1:0]    way_hit;
    reg [N_LINES_W-1:0] addr;

    wire [N_WAYS-1:0]   way_select;
    wire [N_WAYS_W-1:0] way_select_bin;

    cache_replacement #(
        .N_WAYS(N_WAYS),
        .N_LINES(N_LINES)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .we             (we),
        .way_hit        (way_hit),
        .addr           (addr),
        .way_select     (way_select),
        .way_select_bin (way_select_bin)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        way_hit = 4'd0;
        we      = 1'b0;
        addr    = 4'd0;
        #10 
        rst_n = 1;
        
        #10;
        way_hit = 4'b0001;
        addr    = 4'd2;
        we      = 1'b1;
        
        #10;
        way_hit = 4'b0100;
        addr    = 4'd2;
        we      = 1'b1;
        #100 $finish;
    end
endmodule
