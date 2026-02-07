`timescale 1ns/1ps
module dcache_controller (
    input               clk, rst_n,

    // Cache <-> CPU
    input               cpu_req,
    input               cpu_we,
    input               hit,           
    input               victim_dirty,  
    input               victim_valid,      

    input   [2:0]       i_l2_moesi_state,

    output  reg         data_we,
    output  reg         read_index_src,
    output  reg         tag_we, 
    output  reg         refill_we,
    output  reg         stall,

    output  reg         snoop_can_access_ram,
    input               snoop_busy, 

   
    // request L1 -> L2 
    input                       i_mem_req_ready, // L2 san sang nhan
    output  reg                 o_mem_req_valid, // Bao co request
    output  reg [1:0]           o_mem_req_cmd,   // 00: READ_REQ, 01: WRITE_BACK, 10 = UPGRADE/INVALIDATE
    
    // address writeback L1 -> L2
    input                       i_mem_wdata_ready,
    output  reg                 o_mem_wdata_valid,

    // read data L2 -> L1
    input                       i_mem_rdata_valid,
    output  reg                 o_mem_rdata_ready
);
    localparam CMD_READ_SHARED  = 2'b00; // Doc thong thuong
    localparam CMD_WRITE_BACK   = 2'b01; // Ghi tra Victim
    localparam CMD_UPGRADE      = 2'b10; // Xin quyen ghi (Hit Shared)
    localparam CMD_READ_UNIQUE  = 2'b11; // Doc de ghi (Write Miss)

    // MOESI State Encoding
    localparam STATE_M = 3'd0;
    localparam STATE_O = 3'd1;
    localparam STATE_E = 3'd2;
    localparam STATE_S = 3'd3;
    localparam STATE_I = 3'd4;

    // State Encoding
    localparam TAG_CHECK    = 4'd0;
    localparam ALLOC_REQ    = 4'd1;
    localparam ALLOC_WAIT   = 4'd2;
    localparam WB_REQ       = 4'd3;
    localparam WB_DATA      = 4'd4;
    localparam UPDATE       = 4'd5;
    localparam WAIT_SNOOP   = 4'd6;
    localparam WAIT_RAM     = 4'd7;
    localparam UPGRADE_REQ  = 4'd8;

    reg [3:0] state, next_state;

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
                if (cpu_req) begin
                    if (hit) begin
                        // --- [MOI] LOGIC KIEM TRA MOESI ---
                        if (cpu_we) begin
                            // Neu la Shared hoac Owned, phai xin phep Invalidate Core khac
                            if (i_l2_moesi_state == STATE_S || i_l2_moesi_state == STATE_O) begin
                                next_state = UPGRADE_REQ;
                            end 
                            else begin
                                // Neu la E hoac M, duoc phep ghi ngay
                                next_state = TAG_CHECK; 
                            end
                        end
                        else begin
                            // Read Hit -> Khong lam gi ca
                            next_state = TAG_CHECK;
                        end
                    end 
                    else begin
                        // Cache Miss
                        if ((~victim_valid) || (~victim_dirty))
                            next_state = ALLOC_REQ; // Clean -> Read L2
                        else
                            next_state = WB_REQ;    // Dirty -> Write L2
                    end
                end
            end

            UPGRADE_REQ: begin
                if (i_mem_req_ready) begin
                    next_state = TAG_CHECK; 
                end
            end

            // --- WRITE BACK FLOW ---
            WB_REQ: begin
                // Gui address write back xuong L2
                if (i_mem_req_ready) begin
                    next_state = WB_DATA;
                end
            end
            WB_DATA: begin
                // gui tung word ra L2
                if (i_mem_wdata_ready )
                    next_state = ALLOC_REQ; 
            end

            // --- ALLOCATION FLOW (REFILL) ---
            ALLOC_REQ: begin
                // Gui address read xuong L2
                if (i_mem_req_ready) next_state = ALLOC_WAIT;
            end
            ALLOC_WAIT: begin
                if (i_mem_rdata_valid) begin
                    // Neu dang co Snoop chen ngang thi doi
                    if (snoop_busy) begin 
                        next_state = WAIT_SNOOP;
                    end 
                    else begin            
                        next_state = UPDATE;
                    end 
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
            default: next_state = TAG_CHECK;
        endcase
    end

    always @(*) begin
        o_mem_req_valid     = 1'b0;
        o_mem_req_cmd       = 2'b00;
        o_mem_wdata_valid   = 1'b0;
        o_mem_rdata_ready   = 1'b0;
        
        data_we             = 1'b0;
        tag_we              = 1'b0;
        refill_we           = 1'b0;
        stall               = 1'b0;
        read_index_src      = 1'b0;

        case(state)
            TAG_CHECK: begin
                if (hit & cpu_we) begin 
                    data_we = 1'b1;
                end
            end

            UPGRADE_REQ: begin
                o_mem_req_valid = 1'b1;
                o_mem_req_cmd   = CMD_UPGRADE;  // 10 = UPGRADE/INVALIDATE
                stall           = 1'b1;         // Stall CPU den khi xong
            end

            WB_REQ: begin
                o_mem_req_valid = 1'b1;
                o_mem_req_cmd   = CMD_WRITE_BACK;   // 1 = WriteBack
            end

            WB_DATA: begin
                o_mem_wdata_valid = 1'b1;
            end

            // ALLOC_REQ: begin
            //     o_mem_req_valid = 1'b1;
            //     o_mem_req_cmd   = 2'b00; // 0 = Read Request
            // end

            ALLOC_REQ: begin
                o_mem_req_valid = 1'b1;
                if (cpu_we) begin
                    // Write Miss -> Can doc du lieu ve & xin luon quyen ghi
                    o_mem_req_cmd = CMD_READ_UNIQUE; // 2'b11
                end
                else begin
                    // Read Miss -> Chi can doc ve (Shared)
                    o_mem_req_cmd = CMD_READ_SHARED; // 2'b00
                end
            end

            ALLOC_WAIT: begin
                o_mem_req_valid     = 1'b1;
                o_mem_rdata_ready   = 1'b1; // san sang nhan data
            end

            UPDATE: begin
                tag_we      = 1'b1;
                refill_we   = 1'b1;
            end

            WAIT_RAM: begin
                stall           = 1'b1;
                read_index_src  = 1'b1;
            end 
        endcase
    end

    always @(*) begin
        case(state)
            UPDATE, WAIT_RAM: begin
                snoop_can_access_ram = 1'b0;
            end
            WB_DATA: begin
                snoop_can_access_ram = 1'b0;
            end

            default: snoop_can_access_ram = 1'b1;
        endcase
    end

endmodule