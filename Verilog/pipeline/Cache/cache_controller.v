`timescale 1ns/1ps
module cache_controller #(
    parameter DATA_W    = 32,
    parameter ADDR_W    = 32,
    parameter ID_W      = 2,    
    parameter USER_W    = 4,
    parameter STRB_W    = (DATA_W/8),
    parameter BURST_LEN = 15,
    parameter CORE_ID   = 1'b0  // 0: core 0, 1: core 1
)(
    input           clk, rst_n,

    input           snoop_busy,
    output  reg     snoop_can_access_ram,
    output  reg     wb_error,

    // cache <-> cpu
    input           cpu_req,
    input           cpu_we,
    input           hit,           
    input           victim_dirty,  
    input           is_valid,      
    input   [2:0]   current_moesi_state,

    // control plru
    output  reg     plru_we,
    output  reg     plru_src, // 0: way_hit, 1: way_victim

    // control datapath
    output  reg     data_we,
    output  reg     tag_we, 
    output  reg     moesi_we,
    
    output  reg     refill_we,
    output  reg     cache_busy,         // 1: CPU stall, 0: CPU continue
    output  reg     is_shared_response, // 1: Shared, 0: Exclusive
    output  reg     is_dirty_response,  // 1: Dirty, 0: Clean
    // output  reg     way_src,            // 0: way_hit, 1: way_victim
    
    output  [3:0]   cache_state,
    output  reg [3:0]   burst_cnt,

    // cache <-> mem
    // AW channel
    // output      [ID_W-1:0]      oAWID,
    // output      [ADDR_W-1:0]    oAWADDR,
    output      [7:0]           oAWLEN,
    output      [2:0]           oAWSIZE,
    output      [1:0]           oAWBURST,
    output                      oAWLOCK,
    output      [3:0]           oAWCACHE,
    output      [2:0]           oAWPROT,
    output      [3:0]           oAWQOS,
    output      [3:0]           oAWREGION,
    output      [USER_W-1:0]    oAWUSER,
    output  reg                 oAWVALID,
    input                       iAWREADY,
    // tin hieu them ACE
    output  reg [2:0]           oAWSNOOP,
    output      [1:0]           oAWDOMAIN,
    output      [1:0]           oAWBAR,
    output                      oAWUNIQUE,

    // W channel
    // output      [ID_W-1:0]      oWID,       // chua biet gan sao
    // output      [DATA_W-1:0]    oWDATA,
    output  reg [STRB_W-1:0]    oWSTRB,
    output  reg                 oWLAST,
    output      [USER_W-1:0]    oWUSER,
    output  reg                 oWVALID,
    input                       iWREADY,

    // B channel
    input       [ID_W-1:0]      iBID,       // chua su dung
    input       [1:0]           iBRESP,
    input       [USER_W-1:0]    iBUSER,
    input                       iBVALID,
    output  reg                 oBREADY,

    // AR channel
    // output      [ID_W-1:0]      oARID,
    // output      [ADDR_W-1:0]    oARADDR,
    output      [7:0]           oARLEN,
    output      [2:0]           oARSIZE,
    output      [1:0]           oARBURST,
    output                      oARLOCK,
    output      [3:0]           oARCACHE,
    output      [2:0]           oARPROT,
    output      [3:0]           oARQOS,
    output      [USER_W-1:0]    oARUSER,
    output  reg                 oARVALID,
    input                       iARREADY,
    // tin hieu them ACE
    output  reg [3:0]           oARSNOOP,
    output      [1:0]           oARDOMAIN,
    output      [1:0]           oARBAR,

    // R channel
    input       [ID_W-1:0]      iRID,   // chua xu dung
    // input       [DATA_W-1:0]    iRDATA,
    input       [3:0]           iRRESP,
    input                       iRLAST,
    input       [USER_W-1:0]    iRUSER,
    input                       iRVALID,
    output  reg                 oRREADY
);
    localparam IDLE         = 4'd0;
    localparam TAG_CHECK    = 4'd1;
    localparam WB_AW        = 4'd2;
    localparam WB_W         = 4'd3;
    localparam WB_B         = 4'd4;
    localparam ALLOC_AR     = 4'd5;
    localparam ALLOC_R      = 4'd6;
    localparam UPDATE       = 4'd7;
    localparam FAULT        = 4'd8;
    localparam WAIT_SNOOP   = 4'd9;

    localparam  STATE_M = 3'd0,
                STATE_O = 3'd1,
                STATE_E = 3'd2,
                STATE_S = 3'd3,
                STATE_I = 3'd4;

    reg [3:0] state, next_state;
    // reg [3:0] burst_cnt;
    wire need_upgrade;

    assign need_upgrade = cpu_we & ((current_moesi_state == STATE_O) | (current_moesi_state == STATE_S)); // (write o trang thai O / S)

    // --- Constant Assignments ---
    assign oAWLEN       = 8'd15;    // Burst 16
    assign oAWSIZE      = 3'b010;   // 32-bit
    assign oAWBURST     = 2'b01;    // INCR
    assign oAWLOCK      = 1'b0;
    assign oAWCACHE     = 4'd0;
    assign oAWPROT      = 3'd0;
    assign oAWQOS       = 4'd0;
    assign oAWREGION    = 4'd0;
    assign oAWUSER      = {(USER_W){1'b0}};
    assign oWUSER       = {(USER_W){1'b0}};
    assign oARLOCK      = 1'd0;
    assign oARCACHE     = 4'd0;
    assign oARPROT      = 3'd0;
    assign oARQOS       = 3'd0;
    assign oARUSER      = {(USER_W){1'b0}};
    assign oARLEN       = 8'd15;
    assign oARSIZE      = 3'd2;
    assign oARBURST     = 2'b01;    // INCR
    
    // assign oARID        = {ID_W{1'b0}};
    // assign oWID         = {ID_W{1'b0}};
    // assign oAWID        = {ID_W{1'b0}};
    
    // ACE Constants
    assign oARDOMAIN    = 2'b01; // Inner Shareable
    assign oAWDOMAIN    = 2'b01; 
    assign oAWBAR       = 2'b00;
    assign oARBAR       = 2'b00;
    assign oAWUNIQUE    = 1'b0;

    assign cache_state  = state;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state              <= TAG_CHECK;
            burst_cnt          <= 4'd0;
            is_shared_response <= 1'b0;
            is_dirty_response  <= 1'b0;
        end 
        else begin
            state <= next_state;
    
            if (((state == WB_W) & iWREADY) | ((state == ALLOC_R) & iRVALID)) begin
                burst_cnt <= burst_cnt + 1'b1;
            end 
            else if ((state != WB_W) & (state != ALLOC_R)) begin
                burst_cnt <= 4'd0; 
            end

            if ((state == ALLOC_R) & (iRVALID && iRLAST)) begin
                is_shared_response <= iRRESP[2];
            end

            if ((state == ALLOC_R) & (iRVALID && iRLAST)) begin
                is_dirty_response <= iRRESP[3];
            end
        end 
    end 

    // --- Next State Logic ---
    always @(*) begin
        next_state = state;
        case(state)
            // IDLE: begin
            //     next_state = (cpu_req & (~snoop_busy)) ? TAG_CHECK : IDLE; 
            // end 
            
            TAG_CHECK: begin
                if (snoop_busy) begin
                    // next_state = IDLE;
                    next_state = TAG_CHECK; 
                end
                else if (cpu_req) begin
                    if (hit) begin
                        if (need_upgrade) begin
                            next_state = ALLOC_AR;
                        end 
                        else if (cpu_we) begin  // read hit or write hit on E/M
                            next_state = TAG_CHECK;
                        end 
                        else begin
                            // next_state = IDLE;
                            next_state = TAG_CHECK;
                        end 
                    end 
                    else begin
                        // Miss -> Check Victim
                        if ((~is_valid) || (~victim_dirty)) begin
                            next_state = ALLOC_AR; // Victim clean -> allocate
                        end 
                        else begin
                            next_state = WB_AW;    // Victim dirty -> write back
                        end 
                    end 
                end 
            end 

            // --- Write Back ---
            WB_AW: begin
                next_state = (iAWREADY) ? WB_W : WB_AW;
            end 
            WB_W: begin
                // xuat het burst
                next_state = (iWREADY & (burst_cnt == BURST_LEN)) ? WB_B : WB_W;
            end 
            WB_B: begin
                if (iBVALID & ({1'b1, CORE_ID} == iBID)) begin
                    next_state = (iBRESP[1]) ? FAULT : ALLOC_AR;
                end 
                else begin
                    next_state = WB_B;
                end 
            end 

            FAULT: begin
                next_state = WB_W;  // sau khi xu ly loi thi quay lai write back
            end

            // --- Allocation ---
            ALLOC_AR: begin
                next_state = (iARREADY) ? ALLOC_R : ALLOC_AR;
            end 
            ALLOC_R: begin  // ghi data vao buffer
                if (iRVALID & (iRID == {1'b1, CORE_ID}) & iRLAST) begin
                    if (snoop_busy) begin                        
                        next_state = WAIT_SNOOP;
                    end
                    else begin
                        next_state = UPDATE;     
                    end
                end 
                else begin
                    next_state = ALLOC_R;
                end
            end 

            WAIT_SNOOP: begin
                if (~snoop_busy) begin
                    next_state = UPDATE;
                end 
                else begin
                    next_state = WAIT_SNOOP;
                end
            end

            UPDATE: begin
                next_state = TAG_CHECK;
            end 

            default: begin
                // next_state = IDLE;
                next_state = TAG_CHECK;
            end 
        endcase
    end 

    // --- Output Logic ---
    always @(*) begin
        oAWVALID    = 1'd0;
        oAWSNOOP    = 3'd0;
        oWVALID     = 1'd0;
        oWLAST      = 1'd0;
        oBREADY     = 1'd0;
        oARVALID    = 1'd0;
        oARSNOOP    = 4'd0;
        oWSTRB      = 4'd0;
        oRREADY     = 1'd0;
        data_we     = 1'd0;
        tag_we      = 1'd0;
        wb_error    = 1'd0;
        refill_we   = 1'd0;
        // way_src     = 1'b0;
        moesi_we    = 1'd0;
        plru_we     = 1'd0;
        plru_src    = 1'b0;
        
        cache_busy  = 1'b1; // mac dinh la ban (tru IDLE)
        snoop_can_access_ram = 1'b1; // mac dinh la co the truy cap (tru tagcheck | update)

        case(state)
            // IDLE: begin
            //     cache_busy = 1'b0;
            // end 
            TAG_CHECK: begin
                snoop_can_access_ram    = 1'b0;
                if (hit & (~need_upgrade)) begin
                    cache_busy = 1'b0;
                    plru_we    = 1'b1;
                    if (cpu_we) begin
                        // tag_we      = 1'b1;
                        moesi_we    = 1'b1; // update dirty bit state -> M;
                        data_we     = 1'b1;
                    end 
                end 
            end 
            WB_AW: begin
                oAWVALID = 1'b1;
                oAWSNOOP = 3'b011;  // ACE: WriteBack
            end 

            WB_W: begin
                oWVALID = 1'b1;
                oWSTRB  = 4'b1111;
                oWLAST  = (burst_cnt == BURST_LEN);
            end 

            WB_B: begin
                oBREADY = 1'b1;
            end 

            FAULT: begin
                wb_error = 1'b1;
            end 

            ALLOC_AR: begin
                oARVALID = 1'b1;
                if (cpu_we) begin
                    if (hit) begin   
                        // Write Hit  -> CleanUnique
                        oARSNOOP = 4'b1011; 
                    end 
                    else begin       
                        // Write Miss -> ReadUnique (Linefill)
                        oARSNOOP = 4'b0111; 
                    end 
                end
                else begin  // read miss -> ReadShared 
                     oARSNOOP = 4'b0001;
                end
            end

            ALLOC_R: begin
                oRREADY = 1'b1; // san sang doc data tu bus
                // data tu bus du dinh se vao linefill buffer roi ghi vao o state UPDATE (xu ly ở datapath)
            end 

            UPDATE: begin
                snoop_can_access_ram = 1'b0;
                tag_we      = 1'b1;
                moesi_we    = 1'b1;
                plru_we     = 1'b1;
                plru_src    = 1'b1;
                // data_we     = 1'b1;
                refill_we   = 1'b1;
                // way_src     = 1'b1;
            end 
            
            default: begin
            end 
        endcase
    end 
endmodule