`timescale 1ns/1ps
module cache_L2_controller #(
    parameter DATA_W        = 32,
    parameter ADDR_W        = 32,
    parameter ID_W          = 2,    
    parameter USER_W        = 4,
    parameter CACHE_DATA_W  = 512,              // 64 Bytes Line
    parameter STRB_W        = (DATA_W/8)        // strobe width matches beat data width (32-bit -> 4)
)(
    input           clk, rst_n,

    // --- Control Signals ---
    input           snoop_busy,          
    output  reg     snoop_can_access_ram,
    // output  reg     wb_error,

    // --- L1 Interface (Thay cho CPU) ---
    input           i_req_valid,         
    input  [1:0]    i_req_cmd,           // 00: Read, 01: Write, 10: UPGRADE/INVALIDATE
    
    // nhan data tu L1
    input           i_wdata_valid,
    output  reg     o_wdata_ready,       

    // tra data cho L1
    output  reg     o_rdata_ready,       
    
    // Cache Status Inputs
    input           hit,           
    input           victim_dirty,  
    input           is_valid,      
    input   [2:0]   current_moesi_state,

    // --- Control Datapath ---
    // output  reg     data_we,
    output  reg     tag_we, 
    output  reg     moesi_we,
    output  reg     refill_we,
    output  reg     stall,
    
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

    output  reg [STRB_W-1:0]    oWSTRB,
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

    // MOESI State Encoding
    localparam STATE_M = 3'd0;
    localparam STATE_O = 3'd1;
    localparam STATE_E = 3'd2;
    localparam STATE_S = 3'd3;
    localparam STATE_I = 3'd4;

    localparam CMD_READ_SHARED  = 2'b00; 
    localparam CMD_WRITE_BACK   = 2'b01; 
    localparam CMD_UPGRADE      = 2'b10; 
    localparam CMD_READ_UNIQUE  = 2'b11;

    reg [3:0] state, next_state;

    // AXI Constants
    // Use 16 beats (0..15) of 32-bit transfers for a full 512-bit line
    assign oAWLEN       = 8'd15;    // 16 beats
    assign oAWSIZE      = 3'b010;   // 4 byte (32-bit)
    assign oAWBURST     = 2'b01; 
    assign oARLEN       = 8'd15; 
    assign oARSIZE      = 3'b010;   // 4 byte (32-bit)
    assign oARBURST     = 2'b01; 
    assign oARDOMAIN    = 2'b01; 
    assign oAWDOMAIN    = 2'b01; 

    wire need_upgrade;
    // assign need_upgrade = (i_req_cmd == CMD_WRITE_BACK) && hit && ((current_moesi_state == 3'd3) || (current_moesi_state == 3'd1)); // 3=Shared, 1=Owned
    assign need_upgrade =   ( (i_req_cmd == CMD_UPGRADE) || (i_req_cmd == CMD_READ_UNIQUE) ) 
                            || (i_req_cmd == CMD_WRITE_BACK) && hit && ((current_moesi_state == STATE_S) || (current_moesi_state == STATE_O));
                            

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin 
            burst_cnt           <= 4'd0;
            is_shared_response  <= 1'b0;
            is_dirty_response   <= 1'b0;
        end 
        else begin
            // Tang counter khi nhan Data L1 hoac Mem
            if ( ((state == WB_W) && iWREADY) || ((state == ALLOC_R) && iRVALID)) begin
                burst_cnt <= burst_cnt + 1'b1;
            end 
            else if (state != WB_W && state != ALLOC_R) begin
                burst_cnt <= 4'd0; 
            end 

            // Capture Response bits from AXI Read
            if ((state == ALLOC_R) & (iRVALID && iRLAST)) begin
                is_shared_response  <= iRRESP[2];
                is_dirty_response   <= iRRESP[3];
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
            // TAG_CHECK: begin
            //     if (~snoop_busy && i_req_valid) begin
            //         if (hit) begin
            //             if (i_req_cmd == CMD_WRITE_BACK && need_upgrade) begin
            //                 next_state = ALLOC_AR; // Hit Shared -> Xin quyen Unique
            //             end 
            //             else if (i_req_cmd == CMD_WRITE_BACK)
            //                 next_state = L1_WB_RX; // Hit Exclusive/Modified -> Nhan data ghi lun
            //             else
            //                 next_state = TAG_CHECK; // Read Hit -> Xong
            //         end 
            //         else begin // MISS
            //             if (is_valid && victim_dirty) begin
            //                 next_state = WB_AW;    // write back
            //             end 
            //             else 
            //                 next_state = ALLOC_AR; // allocate (ReadUnique/ReadShared)
            //         end
            //     end
            // end

            TAG_CHECK: begin
                if (~snoop_busy && i_req_valid) begin
                    if (hit) begin
                        if (need_upgrade) begin
                            next_state = ALLOC_AR; // Gui CleanUnique
                        end 
                        else if (i_req_cmd == CMD_WRITE_BACK) begin
                            next_state = L1_WB_RX; // Hit M/E -> Ghi ngay
                        end
                        else begin
                            next_state = TAG_CHECK; // Read Hit -> Xong
                        end
                    end 
                    else begin 
                        if (is_valid && victim_dirty) begin
                            next_state = WB_AW;    // Write back victim
                        end 
                        else 
                            next_state = ALLOC_AR; // Allocate (Read Miss)
                    end
                end
            end

            // --- L1 Writeback Receiver ---
            L1_WB_RX: begin
                // ghi 1 luc 512 bit 
                if (i_wdata_valid) next_state = UPDATE; 
            end

            // --- Writeback ---
            WB_AW: begin    
                next_state = (iAWREADY) ? WB_W : WB_AW;
            end 

            WB_W: begin     
                next_state = (iWREADY & (burst_cnt == 4'd15)) ? WB_B : WB_W;
            end 

            WB_B: begin
                if (iBVALID) begin
                    // Xong WB Victim -> Quay lai viec chinh (Nhan data L1 hooc doc Mem)
                    next_state = (i_req_cmd == CMD_WRITE_BACK) ? L1_WB_RX : ALLOC_AR;
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
        oAWVALID                = 1'b0; 
        oWVALID                 = 1'b0; 
        oBREADY                 = 1'b0; 
        oARVALID                = 1'b0; 
        oRREADY                 = 1'b0;
        tag_we                  = 1'b0; 
        moesi_we                = 1'b0;
        refill_we               = 1'b0; 
        o_wdata_ready           = 1'b0; 
        o_rdata_ready           = 1'b0;
        oWLAST                  = 1'b0;
        snoop_can_access_ram    = 1'b0;
        o_req_ready             = 1'b0;
        stall                   = 1'b0;   
        oAWSNOOP                = 3'b0; 
        oARSNOOP                = 4'b0;
        oWSTRB                  = {STRB_W{1'b0}};

        case(state)
            // TAG_CHECK: begin
            //     snoop_can_access_ram = 1'b1;
                
            //     if (i_req_valid && (i_req_cmd == CMD_READ) && hit) begin 
            //         o_rdata_ready = 1'b1;
            //     end
                
            //     if (~snoop_busy && (next_state == TAG_CHECK)) begin
            //         o_req_ready = 1'b1; 
            //     end
            //     else begin
            //         o_req_ready = 1'b0;
            //     end
            // end

            TAG_CHECK: begin
                snoop_can_access_ram = 1'b1;
                
                if (i_req_valid && hit && !need_upgrade) begin
                    if (i_req_cmd == CMD_READ_SHARED || i_req_cmd == CMD_READ_UNIQUE) begin
                        o_rdata_ready = 1'b1;
                    end
                end
                
                if (~snoop_busy && (next_state == TAG_CHECK)) begin
                    o_req_ready = 1'b1; 
                end
                else begin
                    o_req_ready = 1'b0;
                end
            end

            L1_WB_RX: begin
                o_wdata_ready = 1'b1; // Bat co nhan data tu L1
            end

            WB_AW: begin 
                oAWVALID = 1'b1; 
                oAWSNOOP = 3'b011; // WriteBack
            end

            WB_W: begin
                oWVALID = 1'b1;
                oWSTRB  = {STRB_W{1'b1}};
                oWLAST  = (burst_cnt == 4'd15);
            end
            
            WB_B: begin  
                oBREADY = 1'b1;
            end 

            // ALLOC_AR: begin 
            //     oARVALID = 1'b1; 
            //     snoop_can_access_ram = 1'b1; 
            //     if (need_upgrade) begin
            //         // CleanUnique: Bao moi nguoi Invalidate, tao giu data (vi tao sap ghi de)
            //         oARSNOOP = 4'b1011; 
            //     end
            //     else begin
            //         // ReadShared: Doc thong thuong (Miss)
            //         oARSNOOP = 4'b0001; 
            //     end
            // end

            ALLOC_AR: begin 
                oARVALID = 1'b1; 
                snoop_can_access_ram = 1'b1; 
                if (need_upgrade) begin
                    // 1. CleanUnique: Hit S/O hoac Writeback S/O -> Chi can Invalidate
                    oARSNOOP = 4'b1011; 
                end
                else if (i_req_cmd == CMD_READ_UNIQUE) begin
                    // 2. ReadUnique: Write Miss -> Doc ve voi quyen ghi
                    oARSNOOP = 4'b0111;
                end
                else begin
                    // 3. ReadShared: Read Miss -> Doc ve binh thuong
                    oARSNOOP = 4'b0001; 
                end
            end

            ALLOC_R: begin  
                oRREADY = 1'b1; 
                snoop_can_access_ram = 1'b1;
            end 

            // UPDATE: begin
            //     snoop_can_access_ram    = 1'b0;
            //     tag_we                  = 1'b1;
            //     moesi_we                = 1'b1;
            //     refill_we               = 1'b1; 
            // end 

            UPDATE: begin
                snoop_can_access_ram    = 1'b0;
                tag_we                  = 1'b1;
                moesi_we                = 1'b1;
                
                // Chi bat refill_we (Ghi Data RAM) khi thuc su co Data moi
                // - Neu la Upgrade (CleanUnique): Khong co data -> refill_we = 0
                // - Neu la Writeback Upgrade (CMD_WRITE_BACK): Data chua den (se den o L1_WB_RX) -> refill_we = 0
                // - Neu la Read Miss / ReadUnique Miss: Co data tu Bus -> refill_we = 1
                
                if (need_upgrade || (i_req_cmd == CMD_UPGRADE) || (i_req_cmd == CMD_WRITE_BACK)) begin
                     refill_we = 1'b0; // Chi sua Tag/MOESI, giu nguyen Data
                end
                else begin
                     refill_we = 1'b1; // Ghi Data tu Bus vao RAM
                end
            end

            WAIT_SNOOP: begin
                snoop_can_access_ram = 1'b1;
            end

            WAIT_RAM: begin   
                stall = 1'b1;
            end 
        endcase
    end 
endmodule