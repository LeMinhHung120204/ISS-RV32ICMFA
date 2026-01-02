`timescale 1ns/1ps
module snoop_controller #(
    parameter ADDR_W = 32
)(
    input                   clk, rst_n,
    input                   snoop_hit, 
    input                   is_unique, // High if E or M
    input                   is_dirty,  // High if O or M
    input                   is_owner,  // High if O or M

    input                   snoop_can_access_ram,

    output reg              tag_we,
    output reg              snoop_busy,

    output                  bus_rw,
    output                  bus_snoop_valid,
    output  [3:0]           burst_cnt_snoop,

    // AC channel
    input                   ACVALID,
    input   [3:0]           ACSNOOP,
    input   [2:0]           ACPROT,
    // input   [ADDR_W-1:0]    ACADDR,
    output  reg             ACREADY,

    // CR channel
    input                   CRREADY,
    output  reg             CRVALID,
    output  [4:0]           CRRESP,

    // CD channel
    input                   CDREADY,
    output reg              CDLAST,
    output reg              CDVALID
);
    localparam  IDLE    = 2'd0,
                LOOKUP  = 2'd1,
                RESP    = 2'd2,
                DATA    = 2'd3;

    reg [1:0]           state, next_state;
    
    // reg [ADDR_W-1:0]    reg_ACADDR;
    reg [3:0]           reg_ACSNOOP;
    // reg [2:0]           reg_ACPROT;
    reg [4:0]           reg_CRRESP;
    reg [3:0]           burst_cnt;

    reg snoop_requires_data;
    reg snoop_requires_invalidate;
    
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
            4'b0111: begin // ReadUnique
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
    assign bus_snoop_valid  = (state == LOOKUP) & snoop_can_access_ram;

    // --------------------- TINH CRRESP ---------------------
    always @(*) begin
        if (snoop_hit) begin
            // Chi gui data khi co yeu cau va phai co quyen (Owner / Unique)
            resp_dt = snoop_requires_data && (is_owner | is_unique);
            resp_pd = is_dirty && resp_dt;
            resp_is = !snoop_requires_invalidate;
            resp_wu = is_unique;
        end 
        else begin
            resp_dt = 1'b0;
            resp_pd = 1'b0;
            resp_is = 1'b0;
            resp_wu = 1'b0;
        end
    end
    assign CRRESP = reg_CRRESP;

    // --------------------- FSM ---------------------
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state       <= IDLE;
            burst_cnt   <= 4'd0;
        end 
        else begin
            state <= next_state;
            if ((state == DATA) & CDVALID & CDREADY) begin
                burst_cnt <= burst_cnt + 1'b1;
            end else if (state != DATA) begin
                burst_cnt <= 4'd0;
            end
        end
    end

    assign burst_cnt_snoop = burst_cnt;

    // --------------------- next state & output ---------------------
    always @(*) begin
        snoop_busy  = 1'b1;
        ACREADY     = 1'b0;
        CRVALID     = 1'b0;
        CDVALID     = 1'b0;
        CDLAST      = 1'b0;
        tag_we      = 1'b0;
        next_state  = state;

        case (state)
            IDLE: begin
                snoop_busy  = 1'b0;
                ACREADY     = 1'b1;
                if (ACVALID) begin
                    next_state = LOOKUP;
                end
            end

            LOOKUP: begin
                if (snoop_can_access_ram) begin
                    // Lenh bat buoc Invalidate (ReadUnique, MakeInvalid...)
                    // Lenh Read thuong nhung minh dang Unique (E/M) -> S/O
                    if ((snoop_hit & snoop_requires_invalidate) | (snoop_hit & is_unique)) begin    
                        tag_we = 1'b1; 
                    end
                    next_state = RESP;
                end
                else begin
                    next_state = LOOKUP;
                end
            end

            RESP: begin
                CRVALID = 1'b1;
                if (CRREADY) begin
                    if (reg_CRRESP[0]) begin // Check bit DataTransfer (bit 0)
                        next_state = DATA;
                    end 
                    else begin
                        next_state = IDLE;
                    end
                end
                else begin
                    next_state = RESP;
                end 
            end

            DATA: begin
                CDVALID     = 1'b1;
                CDLAST      = (burst_cnt == 4'd15);                
                next_state  = (CDREADY & CDLAST) ? IDLE : DATA;
            end
            default: begin        
                next_state  = IDLE;
            end 
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // reg_ACADDR  <= 32'd0;
            reg_CRRESP  <= 5'd0;
            reg_ACSNOOP <= 4'd0;
            // reg_ACPROT  <= 3'd0;
        end else begin
            if ((state == IDLE) & ACVALID & ACREADY) begin
                // reg_ACADDR  <= ACADDR;
                reg_ACSNOOP <= ACSNOOP;
                // reg_ACPROT  <= ACPROT;
            end

            if ((state == LOOKUP) & snoop_can_access_ram) begin
                reg_CRRESP <= {resp_wu, resp_is, resp_pd, 1'b0, resp_dt};
            end
        end
    end

endmodule