`timescale 1ns/1ps
`include "define.vh"

module tb_soc_top2;
    logic ACLK;
    logic ARESETn;

    vc707_soc #(
        .MEM_BASE       (`MEM_BASE)
    ,   .CODE_A_START   (`CODE_A_START)
    ,   .CODE_B_START   (`CODE_B_START)
    ,   .DATA_START     (`DATA_START)
    ,   .NUM_WAYS       (`NUM_WAYS)
    ,   .NUM_SETS       (`NUM_SETS)
    ,   .NUM_SETS_L2    (`NUM_SETS_L2)
    ,   .WORD_OFF_W     (`WORD_OFF_W)
    ,   .BYTE_OFF_W     (`BYTE_OFF_W)
    ,   .DATA_W         (`DATA_W)
    ,   .RAM_ADDR_W     (`RAM_ADDR_W)
    ,   .FF_DEPTH       (`FF_DEPTH)
    ,   .RESET_VALUE    (`RESET_VALUE)
    ) dut (
        // Clock and Reset
        .ACLK           (ACLK)
    ,   .ARESETn        (ARESETn)

        // AXI 4 Lite Slave Interface
    ,   .s00_axi_awaddr ()
    ,   .s00_axi_awprot ()
    ,   .s00_axi_awvalid()
    ,   .s00_axi_awready()

    ,   .s00_axi_wdata  ()
    ,   .s00_axi_wstrb  ()
    ,   .s00_axi_wvalid ()
    ,   .s00_axi_wready ()

    ,   .s00_axi_bresp  ()
    ,   .s00_axi_bvalid ()
    ,   .s00_axi_bready ()

    ,   .s00_axi_araddr ()
    ,   .s00_axi_arprot ()
    ,   .s00_axi_arvalid()
    ,   .s00_axi_arready()

    ,   .s00_axi_rdata  ()
    ,   .s00_axi_rresp  ()
    ,   .s00_axi_rvalid ()
    ,   .s00_axi_rready ()
    );

    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    initial begin
        ARESETn = 0;
        #20;
        ARESETn = 1;
        #1000;
        $finish;
    end 
endmodule 