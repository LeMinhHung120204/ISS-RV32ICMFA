`timescale 1ns/1ps
module l2_cache_controller #(
    parameter DATA_W    = 32,
    parameter ADDR_W    = 32,
    parameter ID_W      = 2,    
    parameter USER_W    = 4,
    parameter BURST_LEN = 15, // 16 words
    parameter CORE_ID   = 1'b0
)(
    input           clk, rst_n,

    // --- Control Signals ---
    input           snoop_busy,          
    output  reg     snoop_can_access_ram,
    output  reg     wb_error,

    // --- L1 Interface (Thay cho CPU) ---
    input           i_req_valid,         
    input  [1:0]    i_req_cmd,           // 00: Read, 01: Write
    
    // nhan data tu L1
    input           i_wdata_valid,
    input           i_wdata_last,
    output  reg     o_wdata_ready,       

    // tra data cho L1
    output  reg     o_rdata_ready,       
    
    // Cache Status Inputs
    input           hit,           
    input           victim_dirty,  
    input           is_valid,      
    input   [2:0]   current_moesi_state,

    // --- Control Datapath ---
    output  reg     data_we,
    output  reg     tag_we, 
    output  reg     moesi_we,
    output  reg     refill_we,
    
    output  reg         is_shared_response, 
    output  reg         is_dirty_response,  
    output  reg         o_req_ready,        // Bao cho L1 biet L2 san sang nhan lenh CMD/ADDR
    output  reg [3:0]   burst_cnt,

    // --- AXI Interface  ---
    output      [7:0]           oAWLEN,
    output      [2:0]           oAWSIZE,
    output      [1:0]           oAWBURST,
    output  reg                 oAWVALID,
    input                       iAWREADY,
    output  reg [2:0]           oAWSNOOP,
    output      [1:0]           oAWDOMAIN,

    output  reg [DATA_W/8-1:0]  oWSTRB,
    output  reg                 oWLAST,
    output  reg                 oWVALID,
    input                       iWREADY,
    
    input       [ID_W-1:0]      iBID,
    input       [1:0]           iBRESP,
    input                       iBVALID,
    output  reg                 oBREADY,

    output      [7:0]           oARLEN,
    output      [2:0]           oARSIZE,
    output      [1:0]           oARBURST,
    output  reg                 oARVALID,
    input                       iARREADY,
    output  reg [3:0]           oARSNOOP,
    output      [1:0]           oARDOMAIN,

    input       [ID_W-1:0]      iRID,
    input       [3:0]           iRRESP,
    input                       iRLAST,
    input                       iRVALID,
    output  reg                 oRREADY
);

    // State Encoding
    localparam TAG_CHECK    = 4'd0;
    localparam L1_WB_RX     = 4'd1;
    localparam WB_AW        = 4'd2;
    localparam WB_W         = 4'd3;
    localparam WB_B         = 4'd4;
    localparam ALLOC_AR     = 4'd5;
    localparam ALLOC_R      = 4'd6;
    localparam UPDATE       = 4'd7;
    localparam FAULT        = 4'd8;
    localparam WAIT_SNOOP   = 4'd9;
    localparam WAIT_RAM     = 4'd10;

    localparam CMD_READ     = 2'b00;
    localparam CMD_WRITE    = 2'b01; 

    reg [3:0] state, next_state;

    // AXI Constants
    assign oAWLEN       = 8'd15; 
    assign oAWSIZE      = 3'b010; 
    assign oAWBURST     = 2'b01; 
    assign oARLEN       = 8'd15; 
    assign oARSIZE      = 3'd2;   
    assign oARBURST     = 2'b01; 
    assign oARDOMAIN    = 2'b01; 
    assign oAWDOMAIN    = 2'b01; 

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin 
            burst_cnt <= 4'd0;
        end 
        else begin
            // Tang counter khi nhan Data L1 hoac Mem
            if ( ((state == WB_W) && iWREADY) || ((state == ALLOC_R) && iRVALID) || ((state == L1_WB_RX) && i_wdata_valid) ) begin
                burst_cnt <= burst_cnt + 1'b1;
            end 
            else if (state != WB_W && state != ALLOC_R && state != L1_WB_RX) begin
                burst_cnt <= 4'd0; 
            end 
        end 
    end 

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin 
            state <= TAG_CHECK;
        end 
        else begin       
            state <= next_state;
        end 
    end 

    always @(*) begin
        next_state = state;
        case(state)
            TAG_CHECK: begin
                if (!snoop_busy && i_req_valid) begin
                    // Case: L1 Writeback (Evict)
                    if (i_req_cmd == CMD_WRITE) begin
                        // Neu L2 Miss nhung Victim Dirty -> Phai WB Victim truoc
                        if (!hit && is_valid && victim_dirty) begin 
                            next_state = WB_AW; 
                        end
                        else begin                                 
                            next_state = L1_WB_RX; // Nhan data lun
                        end 
                    end
                    // Case: L1 Read (Refill)
                    else begin
                        if (hit) begin 
                            next_state = TAG_CHECK;
                        end 
                        else begin
                            if ((~is_valid) || (~victim_dirty)) begin 
                                next_state = ALLOC_AR;
                            end 
                            else begin                                
                                next_state = WB_AW;    
                            end 
                        end 
                    end
                end 
            end 

            // --- L1 Writeback Receiver ---
            L1_WB_RX: begin
                // doii nhan du 16 words tu L1
                if (i_wdata_valid && i_wdata_last) next_state = UPDATE; 
            end

            // --- Writeback ---
            WB_AW: begin    
                next_state = (iAWREADY) ? WB_W : WB_AW;
            end 

            WB_W: begin     
                next_state = (iWREADY & (burst_cnt == BURST_LEN)) ? WB_B : WB_W;
            end 

            WB_B: begin
                if (iBVALID) begin
                    // Xong WB Victim -> Quay lai viec chinh (Nhan data L1 hooc doc Mem)
                    next_state = (i_req_cmd == CMD_WRITE) ? L1_WB_RX : ALLOC_AR;
                end 
                else begin
                    next_state = WB_B;
                end 
            end 

            // --- allocate ---
            ALLOC_AR: begin 
                next_state = (iARREADY) ? ALLOC_R : ALLOC_AR;
            end 

            ALLOC_R: begin
                if (iRVALID & iRLAST) begin
                    next_state = (snoop_busy) ? WAIT_SNOOP : UPDATE;     
                end 
            end 

            WAIT_SNOOP: begin 
                if (~snoop_busy) begin 
                    next_state = UPDATE;
                end 
            end 

            UPDATE: begin    
                next_state = WAIT_RAM;
            end 

            WAIT_RAM: begin   
                next_state = TAG_CHECK;
            end 
            default:    next_state = TAG_CHECK;
        endcase
    end 

    always @(*) begin
        oAWVALID        = 0; 
        oWVALID         = 0; 
        oBREADY         = 0; 
        oARVALID        = 0; 
        oRREADY         = 0;
        tag_we          = 0; 
        refill_we       = 0; 
        o_wdata_ready   = 0; 
        o_rdata_ready   = 0;
        o_req_ready     = 1'b0;
        snoop_can_access_ram = 1'b1;

        case(state)
            TAG_CHECK: begin
                snoop_can_access_ram = 1'b0;
                if (i_req_valid && (i_req_cmd == CMD_READ) && hit) begin 
                    o_rdata_ready = 1'b1;
                end
                if (~snoop_busy) begin
                    // L2 chi nhan lenh moi khi:
                    // dang o trang thai cho (TAG_CHECK)
                    // khong bi Snoop Controller chiem quyen (snoop_busy = 0)
                    o_req_ready = 1'b1; 
                end
            end 

            L1_WB_RX: begin
                o_wdata_ready = 1'b1; // Bat co nhan data tu L1
            end

            WB_AW: begin 
                oAWVALID = 1'b1; 
                oAWSNOOP = 3'b011; 
            end 
            WB_W:  begin 
                oWVALID = 1'b1; 
                oWSTRB  = {DATA_W/8{1'b1}}; 
                oWLAST  = (burst_cnt == BURST_LEN); 
            end 
            WB_B: begin  
                oBREADY = 1'b1;
            end 
            ALLOC_AR: begin 
                oARVALID = 1'b1; 
                oARSNOOP = 4'b0001; 
            end
            ALLOC_R: begin  
                oRREADY = 1'b1; 
            end 
            UPDATE: begin
                snoop_can_access_ram    = 1'b0;
                tag_we                  = 1'b1;
                refill_we               = 1'b1; 
            end 
        endcase
    end 
endmodule