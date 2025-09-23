`timescale 1ns/1ps
module tb_RV32I;
    reg  clk, rst_n;
    reg [10:0] count_clock;

    // I-MEM wires
    wire [31:0] imem_addr;
    wire [31:0] imem_instr;

    // D-MEM wires
    wire [7:0]  dmem_addr;   
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire        W_Result_output;

    // DUT
    RV32I dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .W_Result_output(W_Result_output)
//        // instruction memory
//        .imem_addr  (imem_addr),
//        .imem_instr (imem_instr),

//        // data memory
//        .dmem_addr  (dmem_addr),
//        .dmem_wdata (dmem_wdata),
//        .dmem_rdata (dmem_rdata),
//        .dmem_we    (dmem_we)
    );

//    // Instruction ROM
//    Ins_Mem imem (
//        .addr        (imem_addr),
//        .instruction (imem_instr)
//    );

//    // Data RAM
//    DataMem dmem (
//        .clk      (clk),
//        .rst_n    (rst_n),
//        .MemWrite (dmem_we),
//        .addr     (dmem_addr),
//        .data_in  (dmem_wdata),
//        .rd       (dmem_rdata)
//    );

    // clock & counter
    always #6 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            count_clock <= 11'd0;
        end 
        else begin 
            count_clock <= count_clock + 1'b1;
        end 
    end

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;

        // $dumpfile("rv32i.vcd");
        // $dumpvars(0, tb_RV32I);

        #50  rst_n = 1'b1;
        #500 $finish;
    end
endmodule
