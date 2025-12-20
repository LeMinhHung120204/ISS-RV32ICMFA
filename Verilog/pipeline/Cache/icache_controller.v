`timescale 1ns/1ps
module icache_controller #(
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
    output  [7:0]           oAWLEN,
    output  [2:0]           oAWSIZE,
    output  [1:0]           oAWBURST,
    output                  oAWLOCK,
    output  [3:0]           oAWCACHE,
    output  [2:0]           oAWPROT,
    output  [3:0]           oAWQOS,
    output  [3:0]           oAWREGION,
    output  [USER_W-1:0]    oAWUSER,
    output                  oAWVALID,

    // W channel
    output  [STRB_W-1:0]    oWSTRB,
    output                  oWLAST,
    output  [USER_W-1:0]    oWUSER,
    output                  oWVALID,

    // B channel
    output                  oBREADY,

    // AR channel
    input                   iARREADY,
    output  reg [ID_W-1:0]  oARID,      // ???
    output  reg [7:0]       oARSIZE,
    output  reg [1:0]       oARBURST,
    output                  oARLOCK,
    output  [3:0]           oARCACHE,
    output  [2:0]           oARPROT,
    output  [3:0]           oARQUOS,
    output  [USER_W-1:0]    oARUSER,
    output  reg             oARVALID,

    // R channel
    input                   iRLAST,
    output  reg             oRREADY

);
    localparam  COMPARE_TAG     = 0,
                ALLOCATE        = 1;

    reg state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
        end 
        else begin
            state <= next_state;
        end 
    end 
    // ---------------------------------------- signal not used ----------------------------------------
    assign  oAWID       = 2'd0,
            oAWLEN      = 8'd0,
            oAWSIZE     = 3'd0,
            oAWBURST    = 2'd0,
            oAWLOCK     = 1'd0,
            oAWCACHE    = 4'd0,
            oAWPROT     = 3'd0,
            oAWQOS      = 4'd0,
            oAWREGION   = 4'd0,
            oAWUSER     = 4'd0,
            oAWVALID    = 1'd0,
            oWSTRB      = 4'd0,
            oWLAST      = 1'd0,
            oWUSER      = 4'd0,
            oWVALID     = 1'd0,
            oBREADY     = 1'd0;

    assign  oARLOCK     = 1'd0,
            oARCACHE    = 4'd0,
            oARPROT     = 3'd0,
            oARQUOS     = 4'd0,
            oARUSER     = 4'd0;
    // ---------------------------------------- next state & output ----------------------------------------
    always @(*) begin
        case(state)
            COMPARE_TAG: begin
                // tin hieu xuat dia chi doc Mem
                oARID       = 2'd0;
                oARLEN      = 4'd0;
                oARSIZE     = 3'd0;  
                oARBURST    = 2'd0;
                oARVALID    = 1'd0;

                // tin hieu ready khi doc Mem
                oRREADY     = 1'd0;

                tag_we      = 1'b0;
                data_we     = 1'b0;
                cache_busy  = 1'b0;
                next_state  = (hit) ? COMPARE_TAG : ALLOCATE;
            end 
            ALLOCATE: begin
                // tin hieu xuat dia chi doc Mem
                oARID       = iARID;
                oARLEN      = 4'd15;    // 15 burst
                oARSIZE     = 3'd2;     // 2^2 byte     
                oARBURST    = 2'b01;    // burst type: inc 
                oARVALID    = 1'd1;

                // tin hieu ready khi doc Mem
                oRREADY     = 1'd1;

                tag_we      = 1'b0;
                data_we     = 1'b1;
                cache_busy  = 1'b1:
                next_state  = (iRLAST) ? ALLOCATE : COMPARE_TAG;
            end 
            default: begin
                oARID       = 2'd0;
                oARLEN      = 4'd0;
                oARSIZE     = 3'd0;
                oARBURST    = 2'd0;
                oARVALID    = 1'd0;
                oRREADY     = 1'd0;
                tag_we      = 1'b0;
                data_we     = 1'b0;
                cache_busy  = 1'b0;
                next_state  = COMPARE_TAG;
            end 
        endcase
    end 
endmodule