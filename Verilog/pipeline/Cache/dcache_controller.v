module dcache_controller #(
    parameter DATA_W    = 32,
    parameter ID_W      = 2,    
    parameter USER_W    = 4,
    parameter STRB_W    = (DATA_W/8)
)(
    input       clk, rst_n, hit,
    output reg  data_we, tag_we, cache_busy,

    // cache <-> mem
    // AW channel
    output  [ID_W-1:0]      oAWID,
    output  [ADDR_W-1:0]    oAWADDR,
    output  [7:0]           oAWLEN,
    output  [2:0]           oAWSIZE,
    output  [1:0]           oAWBURST,
    output                  oAWLOCK,    // khong dung
    output  [3:0]           oAWCACHE,   // khong dung
    output  [2:0]           oAWPROT,    // khong dung
    output  [3:0]           oAWQOS,     // khong dung
    output  [3:0]           oAWREGION,  // khong dung
    output  [USER_W-1:0]    oAWUSER,    // khong dung
    output                  oAWVALID,
    input                   iAWREADY,
    // tin hieu them
    output  [2:0]           oAWSNOOP,
    output  [1:0]           oAWDOMAIN,
    output  [1:0]           oAWBAR,     // must be 1'b0: normal access
    output                  oAWUNIQUE,  // khong dung (=0) vi khong co cache L3

    // W channel
    output  [STRB_W-1:0]    oWSTRB,
    output                  oWLAST,
    output  [USER_W-1:0]    oWUSER,
    output                  oWVALID,

    // B channel
    input                   iBID,
    input                   iBRESP,
    input                   iBUSER,     // khong dung
    input                   iBVALID,
    output                  oBREADY,

    // AR channel
    output  [ID_W-1:0]      oARID,
    output  [ADDR_W-1:0]    oARADDR,
    output  [7:0]           oARLEN,
    output  [3:0]           oARSIZE,
    output  [1:0]           oARBURST,
    output                  oARLOCK,    // khong dung
    output  [3:0]           oARCACHE,   // khong dung 
    output  [2:0]           oARPROT,    // khong dung
    output  [3:0]           oARQUOS,    // khong dung
    output  [USER_W-1:0]    oARUSER,    // khong dung
    output  reg             oARVALID,
    input                   iARREADY,
    // tin hieu them
    output  [3:0]           oARSNOOP,
    output  [1:0]           oARDOMAIN,
    output  [1:0]           oARBAR,     // must be 1'b0: normal access

    // R channel
    input                   iRID,
    input   [DATA_W-1:0]    iRDATA,
    //  RRESP[3:2] (interconnect)
    //  RRESP[1:0] (memory)
    input   [3:0]           iRRESP,
    input                   iRLAST,
    input   [USER_W-1:0]    iRUSER,     // khong dung
    input                   iRVALID,
    output  reg             oRREADY,
);
endmodule