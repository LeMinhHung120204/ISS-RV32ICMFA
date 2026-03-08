`timescale 1ns/1ps
// from Lee Min Hunz with luv

module dcache_controller_v2 (
    input               clk
,   input               rst_n

    // Cache <-> CPU
,   input               cpu_req
,   input               cpu_we
,   input   [31:0]      cpu_addr 

    // Cache Status
,   input               hit         
,   input               victim_dirty
,   input               victim_valid

    // Atomic Interface
,   input                   i_atomic_lr     // Load-Reserved
,   input                   i_atomic_sc     // Store-Conditional  
,   input                   i_atomic_amo    // AMO operation
,   output  reg             o_sc_success    // SC result (0=success, 1=fail)
,   output  reg             sc_done


    // Snoop invalidation (tu L2)
,   input                   i_snoop_invalidate
,   input   [31:0]          i_snoop_addr 

    // Cache Memory Control
,   output  reg         data_we
,   output  reg         read_index_src
,   output  reg         tag_we
,   output  reg         refill_we
,   output  reg         stall

,   output  reg         snoop_stall
,   input               snoop_busy 
    
    // Request L1 -> L2 
,   input                   i_mem_req_ready // L2 san sang nhan
,   output  reg             o_mem_req_valid // Bao co request
,   output  reg [1:0]       o_mem_req_cmd   // 00: READ_REQ, 01: WRITE_BACK, 10 = UPGRADE
    
    // Address Writeback L1 -> L2
,   input                   i_mem_wdata_ready
,   output  reg             o_mem_wdata_valid

    // Read Data L2 -> L1
,   input                   i_mem_rdata_valid
,   input   [2:0]           i_l2_moesi_state
,   output  reg             o_mem_rdata_ready
);

    // ================================================================
    // LOCAL PARAMETERS - Command Encoding
    // ================================================================
    localparam CMD_READ_SHARED  = 2'b00; 
    localparam CMD_WRITE_BACK   = 2'b01; 
    localparam CMD_UPGRADE      = 2'b10; // S/O -> E
    localparam CMD_READ_UNIQUE  = 2'b11;

    // ================================================================
    // LOCAL PARAMETERS - MOESI State Encoding
    // ================================================================
    localparam STATE_M = 3'd0;
    localparam STATE_O = 3'd1;
    localparam STATE_E = 3'd2;
    localparam STATE_S = 3'd3;
    localparam STATE_I = 3'd4;

    // ================================================================
    // LOCAL PARAMETERS - FSM State Encoding
    // ================================================================
    localparam TAG_CHECK    = 4'd0;
    localparam ALLOC_REQ    = 4'd1;
    localparam ALLOC_WAIT   = 4'd2;
    localparam WB_REQ       = 4'd3;
    localparam WB_DATA      = 4'd4;
    localparam UPDATE       = 4'd5;
    localparam WAIT_SNOOP   = 4'd6;
    localparam WAIT_RAM     = 4'd7;
    localparam UPGRADE_REQ  = 4'd8;
    localparam SC_CHECK     = 4'd9;     // Store-Conditional check
    localparam AMO_WRITE    = 4'd10;    // AMO: Write phase

    // ================================================================
    // REG DECLARATIONS
    // ================================================================
    // FSM State Registers
    reg [3:0]   state, next_state;

    // for AMO
    reg         amo_done;
    // Reservation Registers (for LR/SC)
    reg         res_valid;
    reg [31:0]  res_addr;

    // ================================================================
    // WIRE DECLARATIONS
    // ================================================================
    // Reservation Hit Check
    wire        res_hit;
    wire        snoop_addr_match;

    // ================================================================
    // DERIVED SIGNALS
    // ================================================================
    // Check if CPU write address matches Reservation
    assign res_hit          = res_valid && (res_addr == cpu_addr);
    assign snoop_addr_match = (cpu_addr[31:6] == i_snoop_addr[31:6]);

    // ================================================================
    // RESERVATION LOGIC (LR/SC)
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            res_valid   <= 1'b0;
            res_addr    <= 32'b0;
        end
        else begin
            // CLEAR reservation khi:
            // 1. Snoop invalidate den cung dia chi (Core khac muon ghi)
            // 2. SC thuc hien (du success hay fail deu xoa reservation)
            if (i_snoop_invalidate && (i_snoop_addr == res_addr)) begin
                res_valid   <= 1'b0; 
            end
            else if (i_atomic_sc && (state == SC_CHECK)) begin
                if (i_l2_moesi_state != STATE_S && i_l2_moesi_state != STATE_O) begin
                    res_valid <= 1'b0;
                end
            end
            // SET reservation khi LR thanh cong
            // Chi set khi Hit va trang thai cache on dinh
            else if (i_atomic_lr && hit && state == TAG_CHECK) begin
                res_valid   <= 1'b1;
                res_addr    <= cpu_addr;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            amo_done <= 1'b0;
            sc_done  <= 1'b0;
        end 
        else begin
            // 1. SET cho lenh AMO
            if (state == AMO_WRITE) begin
                amo_done <= 1'b1;
            end
            // 2. SET cho lenh SC
            else if (state == SC_CHECK && i_l2_moesi_state != STATE_S && i_l2_moesi_state != STATE_O) begin
                amo_done <= 1'b1;
            end
            // 3. Clear
            else if (state == TAG_CHECK && stall == 1'b0) begin
                amo_done <= 1'b0;
            end

            if (state == SC_CHECK) begin
                sc_done <= 1'b1;
            end
            else if (state == TAG_CHECK && stall == 1'b0) begin
                sc_done <= 1'b0;
            end
        end
    end

    // ================================================================
    // FSM STATE UPDATE
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= TAG_CHECK;
        end 
        else begin       
            state <= next_state;
        end
    end

    // ================================================================
    // SC SUCCESS OUTPUT LOGIC (Sequential)
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            o_sc_success <= 1'b1;
        end
        else begin
            if (state == SC_CHECK) begin
                if (res_hit && (i_l2_moesi_state == STATE_E || i_l2_moesi_state == STATE_M)) begin
                    o_sc_success <= 1'b0; // SUCCESS
                end
                else if (i_l2_moesi_state != STATE_S && i_l2_moesi_state != STATE_O) begin
                    o_sc_success <= 1'b1; // FAIL
                end
            end
            // Reset bd xly mot instruction moi
            else if (state == TAG_CHECK && cpu_req && !stall) begin
                o_sc_success <= 1'b1; 
            end
        end
    end

    // ================================================================
    // COMBINED NEXT STATE & OUTPUT LOGIC
    // ================================================================
    always @(*) begin
        next_state          = state;
        o_mem_req_valid     = 1'b0;
        o_mem_req_cmd       = 2'b00;
        o_mem_wdata_valid   = 1'b0;
        o_mem_rdata_ready   = 1'b0;
        data_we             = 1'b0;
        tag_we              = 1'b0;
        refill_we           = 1'b0;
        stall               = 1'b1;
        read_index_src      = 1'b0;

        // ----------------------------------------------------------------
        // State Machine
        // ----------------------------------------------------------------
        case(state)
            TAG_CHECK: begin
                if (!cpu_req) begin
                    stall = 1'b0;
                end
                else begin
                    // --- 1. HANDLE MISS ---
                    if (!hit) begin
                        if ((~victim_valid) || (~victim_dirty))
                            next_state = ALLOC_REQ;
                        else
                            next_state = WB_REQ;
                    end
                    // --- 2. HANDLE HIT ---
                    else begin
                        // ------ Output Logic (Stall / WE) ------
                        // SC / AMO
                        if (i_atomic_sc || i_atomic_amo) begin
                            if (amo_done) begin
                                stall = 1'b0; // AMO da xly xong, cho phep instruction tiep theo tien hanh
                            end
                            else begin
                                stall = 1'b1; // Stall cho den khi AMO xly xong
                            end
                            // stall = 1'b1;
                        end
                        // Write / LR in S/O
                        else if ((cpu_we || i_atomic_lr) && (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O)) begin
                            stall = 1'b1;
                        end
                        // Write hit in M/E
                        else if (cpu_we && (i_l2_moesi_state == STATE_M || i_l2_moesi_state == STATE_E)) begin
                            data_we = 1'b1;
                            stall   = 1'b0; 
                        end
                        // Read hit / LR in M/E
                        else if (!cpu_we) begin
                            stall = 1'b0;
                        end

                        // ------ Next State Logic ------
                        // 2a. ATOMIC: Store-Conditional
                        if (i_atomic_sc) begin
                            if (amo_done) 
                                next_state = TAG_CHECK;
                            else          
                                next_state = SC_CHECK;
                            // next_state = SC_CHECK;
                        end
                        // 2b. ATOMIC: Load-Reserved hoac AMO
                        else if (i_atomic_lr || i_atomic_amo) begin
                            if (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O)
                                next_state = UPGRADE_REQ;
                            else if (i_atomic_amo & !amo_done)
                                next_state = AMO_WRITE;
                            else
                                next_state = TAG_CHECK;
                        end
                        // 2c. Normal Write
                        else if (cpu_we) begin
                            if (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O)
                                next_state = UPGRADE_REQ;
                            else
                                next_state = TAG_CHECK;
                        end
                        // 2d. Normal Read
                        else begin
                            next_state = TAG_CHECK;
                        end
                    end
                end
            end

            SC_CHECK: begin
                if (res_hit && (i_l2_moesi_state == STATE_E || i_l2_moesi_state == STATE_M)) begin
                    data_we    = 1'b1;     
                    next_state = WAIT_RAM;
                end
                else if (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O) begin
                    next_state = UPGRADE_REQ; // Fail -> Need Upgrade
                end 
                else begin
                    next_state = TAG_CHECK;   // Fail
                end
            end

            AMO_WRITE: begin
                data_we    = 1'b1;
                next_state = WAIT_RAM;
            end

            UPGRADE_REQ: begin
                o_mem_req_valid = 1'b1;
                o_mem_req_cmd   = CMD_UPGRADE;
                if (i_mem_req_ready) next_state = TAG_CHECK;
            end

            WB_REQ: begin
                o_mem_req_valid = 1'b1;
                o_mem_req_cmd   = CMD_WRITE_BACK;
                if (i_mem_req_ready) next_state = WB_DATA;
            end
            
            WB_DATA: begin
                o_mem_wdata_valid = 1'b1;
                if (i_mem_wdata_ready) next_state = ALLOC_REQ;
            end

            ALLOC_REQ: begin
                o_mem_req_valid = 1'b1;
                //If Write Miss / Atomic -> request Unique (Read Unique)
                if (cpu_we || i_atomic_lr || i_atomic_amo || i_atomic_sc) 
                    o_mem_req_cmd = CMD_READ_UNIQUE;
                else 
                    o_mem_req_cmd = CMD_READ_SHARED;

                if (i_mem_req_ready) next_state = ALLOC_WAIT;
            end

            ALLOC_WAIT: begin
                o_mem_req_valid   = 1'b1;
                o_mem_rdata_ready = 1'b1; 
                if (i_mem_rdata_valid) begin
                    if (snoop_busy) next_state = WAIT_SNOOP;
                    else            next_state = UPDATE;
                end
            end

            WAIT_SNOOP: begin
                if (~snoop_busy) next_state = UPDATE;
            end

            UPDATE: begin
                tag_we     = 1'b1;
                refill_we  = 1'b1;
                next_state = WAIT_RAM;
            end

            WAIT_RAM: begin
                read_index_src = 1'b1;
                next_state     = TAG_CHECK;
            end 
            
            default: begin
                next_state = TAG_CHECK;
            end
        endcase
    end

    // ================================================================
    // SNOOP STALL LOGIC (ADDRESS COLLISION)
    // ================================================================
    always @(*) begin
        case(state)
            AMO_WRITE, SC_CHECK, UPDATE: snoop_stall = snoop_addr_match;
            default: snoop_stall = 1'b0;
        endcase
    end

endmodule