`timescale 1ns/1ps
module snoop_controller #(
    parameter ADDR_W = 32
)(
    input                   clk, rst_n,
    
    // thong tin tu L2 Tag & State
    input                   snoop_hit, 
    input                   is_unique, // High if E or M
    input                   is_dirty,  // High if O or M
    input                   is_owner,  // High if O or M

    // thong tin snoop tu L1 (Forwarding result)
    input                   i_l1_snoop_complete, // L1 bao da check xong
    input                   i_l1_is_dirty,       // L1 bao co data dirty
    input                   i_l1_has_data,       // L1 co giu copy

    input                   snoop_can_access_ram,

    output reg              tag_we,
    output reg              snoop_busy,
    output reg              l1_forward_valid,

    // Tin hieu dieu khien MOESI Controller
    output                  bus_rw,             // 1: Write (Invalidate), 0: Read
    output reg              bus_snoop_valid,    // Trigger update MOESI state
    
    output  [3:0]           burst_cnt_snoop,
    output reg              use_l1_data_mux,    // Chon data từ L1 hay L2 RAM

    // AC channel (Address / Control Input)
    input                   ACVALID,
    input   [3:0]           ACSNOOP,
    input   [2:0]           ACPROT,
    output  reg             ACREADY,

    // CR channel (Response Output)
    input                   CRREADY,
    output  reg             CRVALID,
    output  [4:0]           CRRESP,

    // CD channel (Data Output)
    input                   CDREADY,
    output reg              CDLAST,
    output reg              CDVALID
);
    localparam  IDLE    = 3'd0,
                LOOKUP  = 3'd1,
                WAIT_L1 = 3'd2,
                RESP    = 3'd3,
                DATA    = 3'd4;

    reg [2:0]   state, next_state;
    reg [3:0]   reg_ACSNOOP;
    reg [4:0]   reg_CRRESP;
    reg [3:0]   burst_cnt;

    reg snoop_requires_data;
    reg snoop_requires_invalidate;
    
    reg final_is_dirty;
    reg final_has_data;
    reg resp_dt, resp_pd, resp_is, resp_wu;

    // -------------------------------- DECODER ACSNOOP --------------------------------
    always @(*) begin
        case (reg_ACSNOOP)    
            4'b0000: begin // ReadOnce
                snoop_requires_data       = 1'b1;
                snoop_requires_invalidate = 1'b0;
            end
            4'b0001, 4'b0010, 4'b0011: begin // ReadShared, ReadClean, ReadNotSharedDirty
                snoop_requires_data       = 1'b1;
                snoop_requires_invalidate = 1'b0;
            end
            4'b0111: begin // ReadUnique (doc de ghi de -> Invalidate mình)
                snoop_requires_data       = 1'b1;
                snoop_requires_invalidate = 1'b1;
            end
            4'b1000: begin // CleanShared
                snoop_requires_data       = 1'b0; 
                snoop_requires_invalidate = 1'b0;
            end
            4'b1001: begin // CleanInvalid
                snoop_requires_invalidate = 1'b1;
                snoop_requires_data       = 1'b1;
            end
            4'b1101: begin // MakeInvalid
                snoop_requires_invalidate = 1'b1;
                snoop_requires_data       = 1'b0;
            end
            default: begin
                snoop_requires_data       = 1'b0;
                snoop_requires_invalidate = 1'b0;
            end
        endcase
    end

    assign bus_rw           = snoop_requires_invalidate;
    assign burst_cnt_snoop  = burst_cnt;
    assign CRRESP           = reg_CRRESP;

    // --------------------- LOGIC TINH CRRESP (Gop L1 + L2) ---------------------
    always @(*) begin
        final_is_dirty = is_dirty | i_l1_is_dirty;
        final_has_data = is_owner | is_unique | i_l1_has_data; 

        if (snoop_hit) begin
            // Data Transfer (dt): Gui data neu snoop can va minh co data
            resp_dt = snoop_requires_data & final_has_data;
            
            // Pass Dirty (pd): Bao dirty neu minh giu ban dirty va co gui data
            resp_pd = final_is_dirty & resp_dt;
            
            // Is Shared (is): Bao shared neu minh khong bi invalidate (van giu copy)
            resp_is = !snoop_requires_invalidate;
            
            // Was Unique (wu): Bao truoc do minh doc quyen
            resp_wu = is_unique;
        end 
        else begin
            resp_dt = 1'b0; 
            resp_pd = 1'b0; 
            resp_is = 1'b0; 
            resp_wu = 1'b0;
        end
    end

    // --------------------- FSM ---------------------
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state           <= IDLE;
            burst_cnt       <= 4'd0;
            reg_CRRESP      <= 5'd0;
            reg_ACSNOOP     <= 4'd0;
            use_l1_data_mux <= 1'b0;
        end 
        else begin
            state <= next_state;
            if ((state == IDLE) & ACVALID & ACREADY) begin
                reg_ACSNOOP <= ACSNOOP;
            end

            // Logic Latch Response (CRRESP) và Mux Select
            // L2 Miss tại LOOKUP
            // L2 Hit va L1 da tra loi xong tai WAIT_L1
            if ( (state == LOOKUP && snoop_can_access_ram && !snoop_hit) || (state == WAIT_L1 && i_l1_snoop_complete) ) begin
                reg_CRRESP <= {resp_wu, resp_is, resp_pd, 1'b0, resp_dt};
                
                // quyet dinh xem Data gui di (neu co) lay tu dau?
                // Neu L1 bao Dirty -> uu tien lay data moi nhat từ L1
                if (snoop_hit && i_l1_is_dirty) 
                    use_l1_data_mux <= 1'b1;
                else
                    use_l1_data_mux <= 1'b0; // lay tu L2 RAM
            end

            if ((state == DATA) & CDVALID & CDREADY) begin
                burst_cnt <= burst_cnt + 1'b1;
            end else if (state != DATA) begin
                burst_cnt <= 4'd0;
            end
        end
    end

    // --------------------- NEXT STATE & OUTPUT ---------------------
    always @(*) begin
        snoop_busy          = 1'b1;
        ACREADY             = 1'b0;
        CRVALID             = 1'b0;
        CDVALID             = 1'b0;
        CDLAST              = 1'b0;
        tag_we              = 1'b0;
        bus_snoop_valid     = 1'b0;
        l1_forward_valid    = 1'b0;
        next_state          = state;

        case (state)
            IDLE: begin
                snoop_busy = 1'b0;
                ACREADY    = 1'b1;
                if (ACVALID) begin
                    next_state = LOOKUP;
                end
            end

            LOOKUP: begin
                if (snoop_can_access_ram) begin
                    if (snoop_hit) begin
                        // HIT: Phai hoi L1 truoc khi tra loi
                        next_state = WAIT_L1;
                    end 
                    else begin
                        // MISS: Tra loi lun (L2 Miss -> L1 chac chan Miss)
                        next_state = RESP;
                    end
                end
            end

            WAIT_L1: begin
                l1_forward_valid = 1'b1;
                if (i_l1_snoop_complete) begin
                    if ((snoop_requires_invalidate) || is_unique) begin
                        tag_we          = 1'b1; 
                        bus_snoop_valid = 1'b1;
                    end
                    next_state = RESP;
                end
            end

            RESP: begin
                CRVALID = 1'b1;
                if (CRREADY) begin
                    if (reg_CRRESP[0]) begin 
                        next_state = DATA; // Can gui data -> Sang DATA state
                    end 
                    else begin
                        next_state = IDLE;
                    end
                end
            end

            DATA: begin
                CDVALID = 1'b1;
                CDLAST  = (burst_cnt == 4'd15);
                
                if (CDREADY && CDLAST) begin
                    next_state = IDLE;
                end 
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule