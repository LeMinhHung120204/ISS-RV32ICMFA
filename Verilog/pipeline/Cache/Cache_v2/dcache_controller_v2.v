`timescale 1ns/1ps

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

    // Command Encoding
    localparam CMD_READ_SHARED  = 2'b00; 
    localparam CMD_WRITE_BACK   = 2'b01; 
    localparam CMD_UPGRADE      = 2'b10; 
    localparam CMD_READ_UNIQUE  = 2'b11; 

    // MOESI State Encoding
    localparam STATE_M = 3'd0;
    localparam STATE_O = 3'd1;
    localparam STATE_E = 3'd2;
    localparam STATE_S = 3'd3;
    localparam STATE_I = 3'd4;

    // FSM State Encoding
    localparam TAG_CHECK    = 4'd0;
    localparam ALLOC_REQ    = 4'd1;
    localparam ALLOC_WAIT   = 4'd2;
    localparam WB_REQ       = 4'd3;
    localparam WB_DATA      = 4'd4;
    localparam UPDATE       = 4'd5;
    localparam WAIT_SNOOP   = 4'd6;
    localparam WAIT_RAM     = 4'd7;
    localparam UPGRADE_REQ  = 4'd8;
    localparam SC_CHECK     = 4'd9;  // Store-Conditional check
    // localparam AMO_READ     = 4'd10; // AMO: Read phase
    localparam AMO_WRITE    = 4'd10; // AMO: Write phase

    reg [3:0]   state, next_state;
    // ============ RESERVATION REGISTERS ============
    reg                 res_valid;
    reg [31:0]          res_addr;
    
    // Kiem tra xem dia chi CPU dang ghi co khop voi Reservation ko
    wire res_hit = res_valid && (res_addr == cpu_addr);

    // ============ RESERVATION LOGIC ============
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

    // ============ FSM UPDATE ============
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= TAG_CHECK;
        end 
        else begin       
            state <= next_state;
        end
    end

    // ============ OUTPUT LOGIC (Sequential) ============
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            o_sc_success <= 1'b0;
        end
        else begin
            if (state == SC_CHECK) begin
                if (res_hit && (i_l2_moesi_state == STATE_E || i_l2_moesi_state == STATE_M)) begin
                    o_sc_success <= 1'b1; // SUCCESS
                end
                else if (i_l2_moesi_state != STATE_S && i_l2_moesi_state != STATE_O) begin
                    o_sc_success <= 1'b0; // FAIL
                end
            end
            // Reset bd xly mot instruction moi
            else if (state == TAG_CHECK && cpu_req && !stall) begin
                o_sc_success <= 1'b0; 
            end
        end
    end

    // ============ NEXT STATE LOGIC ============
    always @(*) begin
        next_state      = state;
        case(state)
            TAG_CHECK: begin
                if (cpu_req) begin
                    // --- 1. HANDLE MISS ---
                    if (!hit) begin
                         if ((~victim_valid) || (~victim_dirty))
                            next_state = ALLOC_REQ; // Clean -> Read L2
                        else
                            next_state = WB_REQ;    // Dirty -> Write L2
                    end
                    // --- 2. HANDLE HIT ---
                    else begin
                        // 2a. ATOMIC: Store-Conditional
                        if (i_atomic_sc) begin
                            next_state = SC_CHECK;
                        end
                        // 2b. ATOMIC: Load-Reserved hoac AMO
                        // Bat buoc phai co quyen GHI (M hoac E) moi duoc lam
                        else if (i_atomic_lr || i_atomic_amo) begin
                            if (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O)
                                next_state = UPGRADE_REQ; // Hit S -> Can Upgrade
                            else if (i_atomic_amo)
                                next_state = AMO_WRITE;    // Hit M/E -> Bat dau AMO
                            else
                                next_state = TAG_CHECK;   // Hit M/E + LR -> Xong luon (vi LR chi la Load)
                        end
                        // 2c. Normal Write
                        else if (cpu_we) begin
                            if (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O)
                                next_state = UPGRADE_REQ;
                            else
                                next_state = TAG_CHECK; // Write Hit M/E -> Xong
                        end
                        // 2d. Normal Read
                        else begin
                            next_state = TAG_CHECK;
                        end
                    end
                end
            end

            // ============ SC Logic ============
            SC_CHECK: begin
                // kiem tra xem co quyen ghi (M/E) va Reservation con hieu luc khong
                if (res_hit && (i_l2_moesi_state == STATE_E || i_l2_moesi_state == STATE_M)) begin
                    // Success -> Ghi vao Cache (set Dirty) -> Xong
                    next_state      = WAIT_RAM; 
                end
                else if (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O) begin
                    // Neu Hit ma la S/O thi phai Upgrade truoc khi thu SC
                    next_state = UPGRADE_REQ; // Fail
                end 
                else begin
                    next_state = TAG_CHECK; // Fail
                        
                end
            end

            // ============ AMO Flow ============
            // AMO_READ: begin
            //     if (i_mem_rdata_valid) begin
            //         next_state = AMO_WRITE;
            //     end
            // end
            
            AMO_WRITE: begin
                // Ghi ket qua ALU vao lai Cache
                next_state = WAIT_RAM;
            end

            // ============ Standard Flows ============
            UPGRADE_REQ: begin
                if (i_mem_req_ready) next_state = TAG_CHECK;
            end

            WB_REQ: begin
                if (i_mem_req_ready) next_state = WB_DATA;
            end
            
            WB_DATA: begin
                if (i_mem_wdata_ready) next_state = ALLOC_REQ;
            end

            ALLOC_REQ: begin
                if (i_mem_req_ready) next_state = ALLOC_WAIT;
            end

            ALLOC_WAIT: begin
                if (i_mem_rdata_valid) begin
                    if (snoop_busy) next_state = WAIT_SNOOP;
                    else            next_state = UPDATE;
                end
            end

            WAIT_SNOOP: begin
                if (~snoop_busy) next_state = UPDATE;
            end

            UPDATE: begin
                next_state = WAIT_RAM;
            end

            WAIT_RAM: begin
                next_state = TAG_CHECK;
            end 
            
            default: next_state = TAG_CHECK;
        endcase
    end


    // ============ OUTPUT LOGIC ============
    always @(*) begin
        // Default values
        o_mem_req_valid     = 1'b0;
        o_mem_req_cmd       = 2'b00;
        o_mem_wdata_valid   = 1'b0;
        o_mem_rdata_ready   = 1'b0;
        
        data_we             = 1'b0;
        tag_we              = 1'b0;
        refill_we           = 1'b0;
        stall               = 1'b1;
        read_index_src      = 1'b0;

        case(state)
            TAG_CHECK: begin
                if (!cpu_req) begin
                    stall = 1'b0;
                end
                else if (hit) begin
                    // SC / AMO
                    if (i_atomic_sc || i_atomic_amo) begin
                        stall = 1'b1;
                    end
                    // Write / LR in S/O
                    else if ((cpu_we || i_atomic_lr) && (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O)) begin
                        stall = 1'b1;
                    end
                    // write hit in M/E
                    else if (cpu_we && (i_l2_moesi_state == STATE_M || i_l2_moesi_state == STATE_E)) begin
                        data_we = 1'b1;
                        stall   = 1'b0; 
                    end
                    // read hit / LR in M/E
                    else if (!cpu_we) begin
                        stall = 1'b0;
                    end
                end
            end

            SC_CHECK: begin
                if (res_hit && (i_l2_moesi_state == STATE_E || i_l2_moesi_state == STATE_M)) begin
                    data_we = 1'b1; // Write to cache
                end
            end

            // AMO Flow
            // AMO_READ: begin
            //     o_mem_req_valid = 1'b1;
            //     o_mem_req_cmd   = CMD_READ_UNIQUE; 
            // end

            AMO_WRITE: begin
                data_we         = 1'b1; // Ghi ket qua ALU vao Cache
            end

            // Memory Request Flows
            UPGRADE_REQ: begin
                o_mem_req_valid = 1'b1;
                o_mem_req_cmd   = CMD_UPGRADE;
            end

            WB_REQ: begin
                o_mem_req_valid = 1'b1;
                o_mem_req_cmd   = CMD_WRITE_BACK;
            end

            WB_DATA: begin
                o_mem_wdata_valid = 1'b1;
            end

            ALLOC_REQ: begin
                o_mem_req_valid = 1'b1;
                // Neu la Write Miss hoac Atomic -> Xin quyen Unique (Read Unique)
                if (cpu_we || i_atomic_lr || i_atomic_amo || i_atomic_sc) 
                    o_mem_req_cmd = CMD_READ_UNIQUE; 
                else 
                    o_mem_req_cmd = CMD_READ_SHARED;
            end

            ALLOC_WAIT: begin
                o_mem_req_valid     = 1'b1;
                o_mem_rdata_ready   = 1'b1; 
            end

            UPDATE: begin
                tag_we      = 1'b1;
                refill_we   = 1'b1;
            end

            WAIT_RAM: begin
                read_index_src  = 1'b1;
            end 
        endcase
    end
// ============ SNOOP STALL LOGIC (ADDRESS COLLISION) ============
    wire snoop_addr_match = (cpu_addr[31:6] == i_snoop_addr[31:6]); 

    always @(*) begin
        case(state)
            AMO_WRITE, SC_CHECK, UPDATE: snoop_stall = snoop_addr_match;
            default: snoop_stall = 1'b0;
        endcase
    end

endmodule