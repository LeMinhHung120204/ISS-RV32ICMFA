`timescale 1ns/1ps

module tb_srt_4_div;

    localparam DW = 32;

    reg                   clk;
    reg                   rst_n;
    reg                   start;
    reg  [DW-1:0]         dividend;
    reg  [DW-1:0]         divisor;
    reg  [9:0]            count_clock;
    reg                     is_unsign;
    
    wire [DW-1:0]         quotient;
    wire [DW-1:0]         reminder;
    wire                  mulfinish;
    wire                  diverror;

    initial clk = 1'b0;
    always #2.5 clk = ~clk;
    
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            count_clock <= 10'd0;
        end  
        else begin
            count_clock <= count_clock + 1'b1;
        end 
    end 
  

  //================================================================
  // DUT
  //================================================================
//    srt_4_div #(.DW(DW)) dut (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start(start),
//        .dividend(dividend),
//        .divisor(divisor),
//        .quotient(quotient),
//        .reminder(reminder),
//        .mulfinish(mulfinish),
//        .diverror(diverror)
//    );


    non_restore_v2 dut (
        .clk(clk),
        .rst_n(rst_n),
        .is_unsigned(is_unsign),
        .dividend(dividend),
        .divisor(divisor),
        .quotient(quotient),
        .remainder(reminder)
    );
    
    initial begin  
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        is_unsign = 0;
        
        #10;
        is_unsign = 0;
        rst_n = 1'b1;
        start = 1'b1;
        dividend = -32'd11;
        divisor = 32'd3;

         #10;
         rst_n = 1'b1;
         dividend = 32'd10;
         divisor = 32'd5;
         
         #10;
         rst_n = 1'b1;
         dividend = 32'd128;
         divisor = 32'd13;
        
        #200;
        $finish;
    end

endmodule
