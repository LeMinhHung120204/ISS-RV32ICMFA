`timescale 1ns/1ps

module core_tile #(
    parameter core_id = 0
)(
    input clk,
    input rst_n,
);
    dcache #(
        .ADDR_W(32),
        .DATA_W(32)
    ) u_dcache (
        .ACLK       (clk),
        .ARESETn    (rst_n),

        // CPU Interface
        .cpu_req    (data_req),
        .cpu_size   (data_size),
        .data_valid (1'b1),
        .cpu_we     (data_wr),
        .cpu_addr   (data_addr),
        .cpu_din    (data_wdata),

        .data_rdata (data_rdata),
        .cpu_hit    (),

        // AXI Interface
        // AW Channel
        .iAWREADY   (),
        .oAWID      (),
        .oAWADDR    (),
        .oAWLEN     (),
        .oAWSIZE    (),
        .oAWBURST   (),
        .oAWVALID   (),
        // ACE Extensions
        .oAWSNOOP   (),
        .oAWDOMAIN  (),
        .oAWBAR     (),
        .oAWUNIQUE  (), // khong dung

        // W Channel
        .iWREADY    (),
        .oWID       (),
        .oWDATA     (),
        .oWSTRB     (),
        .oWLAST     (),
        .oWVALID    (),

        // B Channel
        .iBID       (),
        .iBRESP     (),
        .iBVALID    (),
        .oBREADY    (),

        // AR Channel
        .iARREADY   (),
        .oARID      (),
        .oARADDR    (),
        .oARLEN     (),
        .oARSIZE    (),
        .oARBURST   (),
        // ACE Extensions
        .oARSNOOP   (),
        .oARDOMAIN  (),
        .oARBAR     (),

        // R Channel
        .iRID       (),
        .iRDATA     (),
        .iRRESP     (),
        .iRLAST     (),
        .iRUSER     (), // khong dun
        .iRVALID    (),
        .oRREADY    ()

        // Snoop channel
        // AC Channel
        .iACVALID   (),
        .iACADDR    (),
        .iACSNOOP   (),
        .oACREADY   (),

        // CR Channel
        .iCRREADY   (),
        .oCRVALID   (),
        .oCRRESP    (),

        // CD Channel
        .iCDREADY   (),
        .oCDVALID   (),
        .oCDDATA    (),
        .oCDLAST    (),
    );

    RV32IMF #(
        .WIDTH_ADDR (32),
        .WIDTH_DATA (32)
    ) u_RV32IMF (
        .clk        (clk),
        .rst_n      (rst_n),

        // cpu <-> dcache
        .data_rdata (data_rdata),
        .data_req   (data_req  ),
        .data_wr    (data_wr   ),
        .data_size  (data_size ),
        .data_addr  (data_addr ),
        .data_wdata (data_wdata)
        // .W_Result_output ()
    );
endmodule