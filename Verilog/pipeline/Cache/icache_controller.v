`timescale 1ns/1ps
module icache_controller #(
    parameter DATA_W    = 32,
    parameter ADDR_W    = 32,
    parameter ID_W      = 2,    
    parameter USER_W    = 4,
    parameter STRB_W    = (DATA_W/8),
    parameter CORE_ID   = 1'b0,
    parameter BURST_LEN = 15
)(
    input           clk, rst_n,

    // --- Cache <-> CPU Interface ---
    input           cpu_req,
    input           hit,           

    // --- Control PLRU ---
    output  reg     plru_we,
    output  reg     plru_src, // 0: way_hit, 1: way_victim

    // --- Control Datapath ---
    output  reg     tag_we, 
    output  reg     valid_we, 
    
    output  reg     refill_we,
    output  reg     cache_busy,         // 1: CPU stall, 0: CPU continue
    
    output  [3:0]   cache_state,
    output  reg [3:0]   burst_cnt,


    // AR channel (Read Address)
    output      [ID_W-1:0]      oARID,
    output      [7:0]           oARLEN,
    output      [2:0]           oARSIZE,
    output      [1:0]           oARBURST,
    output                      oARLOCK,
    output      [3:0]           oARCACHE,
    output      [2:0]           oARPROT,
    output      [3:0]           oARQOS,
    output      [3:0]           oARREGION,
    output      [USER_W-1:0]    oARUSER,
    output  reg                 oARVALID,
    input                       iARREADY,
    
    // R channel (Read Data)
    input       [ID_W-1:0]      iRID,   
    input       [1:0]           iRRESP,
    input                       iRLAST,
    input       [USER_W-1:0]    iRUSER,
    input                       iRVALID,
    output  reg                 oRREADY
);

    localparam TAG_CHECK    = 3'd1;
    localparam ALLOC_AR     = 3'd2;
    localparam ALLOC_R      = 3'd3;
    localparam UPDATE       = 3'd4;

    reg [2:0] state, next_state;

    // --- AXI4 Constant Assignments ---
    assign oARID        = {ID_W{1'b0}};
    assign oARLEN       = 8'd15;    // Burst 16 transfers
    assign oARSIZE      = 3'b010;   // 4 bytes (32-bit) per transfer
    assign oARBURST     = 2'b01;    // INCR type

    assign oARLOCK      = 1'b0;     // Normal access
    assign oARCACHE     = 4'd0;  
    assign oARPROT      = 3'd0;   
    assign oARQOS       = 4'd0;
    assign oARREGION    = 4'd0;
    assign oARUSER      = {(USER_W){1'b0}};
    
    assign cache_state  = state;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state           <= TAG_CHECK;
            burst_cnt       <= 4'd0;
        end 
        else begin
            state <= next_state;
    
            if ((state == ALLOC_R) & iRVALID) begin
                burst_cnt <= burst_cnt + 1'b1;
            end 
            else if (state != ALLOC_R) begin
                burst_cnt <= 4'd0; 
            end
        end 
    end 

    always @(*) begin
        next_state = state;
        case(state)
            TAG_CHECK: begin
                if (cpu_req) begin
                    if (hit) begin
                         next_state = TAG_CHECK;
                    end 
                    else begin
                        next_state = ALLOC_AR;
                    end 
                end 
            end 

            ALLOC_AR: begin
                next_state = (iARREADY) ? ALLOC_R : ALLOC_AR;
            end 
            
            ALLOC_R: begin  
                if (iRVALID & iRLAST & (iRID == {1'b0, CORE_ID})) begin
                    next_state = UPDATE;     
                end 
                else begin
                    next_state = ALLOC_R;
                end
            end 

            UPDATE: begin
                next_state = TAG_CHECK;
            end 

            default: begin
                next_state = TAG_CHECK;
            end 
        endcase
    end 

    always @(*) begin
        oARVALID    = 1'd0;
        oRREADY     = 1'd0;
        tag_we      = 1'd0;
        refill_we   = 1'd0;
        valid_we    = 1'd0;
        plru_we     = 1'd0;
        plru_src    = 1'b0;
        
        cache_busy  = 1'b1; // Mặc định báo bận để Stall CPU

        case(state)
            TAG_CHECK: begin
                if (hit) begin
                    cache_busy = 1'b0;
                    plru_we    = 1'b1;
                end 
            end 

            ALLOC_AR: begin
                oARVALID = 1'b1; // phat lenh doc
            end

            ALLOC_R: begin
                oRREADY = 1'b1;  // san sang nhan data
            end 

            UPDATE: begin
                tag_we      = 1'b1;    
                valid_we    = 1'b1; 
                plru_we     = 1'b1; 
                plru_src    = 1'b1; 
                refill_we   = 1'b1; 
            end 
            
            default: begin
            end 
        endcase
    end 
endmodule