`timescale 1ns / 1ps

module unit_atomic #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter STRB_WIDTH = 4,
    parameter NUM_CORES  = 2
) (
    input  clk,
    input  rstn,
    
    // ===== MASTER-SIDE CHANNELS (CPU → Memory) =====
    
    //  Read Address Channel (AR)
    input  [ADDR_WIDTH-1:0]  cpu_ar_addr,
    input  [2:0]             cpu_ar_prot,
    input  [ID_WIDTH-1:0]    cpu_ar_id,
    input  [2:0]             cpu_ar_user,
    input                    cpu_ar_lock,
    input                    cpu_ar_valid,
    output                   cpu_ar_ready,
    
    //  Read Data Channel (R)
    output [DATA_WIDTH-1:0]  cpu_r_data,
    output [1:0]             cpu_r_resp,
    output [ID_WIDTH-1:0]    cpu_r_id,
    output                   cpu_r_last,
    output                   cpu_r_valid,
    input                    cpu_r_ready,
    
    //  Write Address Channel (AW)
    input  [ADDR_WIDTH-1:0]  cpu_aw_addr,
    input  [2:0]             cpu_aw_prot,
    input  [ID_WIDTH-1:0]    cpu_aw_id,
    input  [5:0]             cpu_aw_atop,
    input  [2:0]             cpu_aw_user,
    input                    cpu_aw_lock,
    input                    cpu_aw_valid,
    output                   cpu_aw_ready,
    
    //  Write Data Channel (W)
    input  [DATA_WIDTH-1:0]  cpu_w_data,
    input  [STRB_WIDTH-1:0]  cpu_w_strb,
    input                    cpu_w_last,
    input                    cpu_w_valid,
    output                   cpu_w_ready,
    
    //  Write Response Channel (B)
    output [1:0]             cpu_b_resp,
    output [ID_WIDTH-1:0]    cpu_b_id,
    output                   cpu_b_last,
    output                   cpu_b_valid,
    input                    cpu_b_ready,
    
    // ===== SLAVE-SIDE CHANNELS (Memory → CPU) =====
    
    // Read Address (AR)
    output [ADDR_WIDTH-1:0]  mem_ar_addr,
    output [2:0]             mem_ar_prot,
    output [ID_WIDTH-1:0]    mem_ar_id,
    output                   mem_ar_lock,
    output                   mem_ar_valid,
    input                    mem_ar_ready,
    
    // Read Data (R)
    input  [DATA_WIDTH-1:0]  mem_r_data,
    input  [1:0]             mem_r_resp,
    input  [ID_WIDTH-1:0]    mem_r_id,
    input                    mem_r_last,
    input                    mem_r_valid,
    output                   mem_r_ready,
    
    // Write Address (AW)
    output [ADDR_WIDTH-1:0]  mem_aw_addr,
    output [2:0]             mem_aw_prot,
    output [ID_WIDTH-1:0]    mem_aw_id,
    output [5:0]             mem_aw_atop,
    output                   mem_aw_lock,
    output                   mem_aw_valid,
    input                    mem_aw_ready,
    
    // Write Data (W)
    output [DATA_WIDTH-1:0]  mem_w_data,
    output [STRB_WIDTH-1:0]  mem_w_strb,
    output                   mem_w_last,
    output                   mem_w_valid,
    input                    mem_w_ready,
    
    // Write Response (B)
    input  [1:0]             mem_b_resp,
    input  [ID_WIDTH-1:0]    mem_b_id,
    input                    mem_b_last,
    input                    mem_b_valid,
    output                   mem_b_ready,
    
    // ===== SNOOP CHANNELS (Interconnect → Master) =====
    
    //  Snoop Address Channel (AC)
    input  [ADDR_WIDTH-1:0]  snoop_ac_addr,
    input  [3:0]             snoop_ac_snoop,
    input                    snoop_ac_valid,
    output                   snoop_ac_ready,
    
    //  Snoop Response Channel (CR)
    output [3:0]             snoop_cr_resp,
    output                   snoop_cr_valid,
    input                    snoop_cr_ready,
    
    //  Snoop Data Channel (CD)
    output [DATA_WIDTH-1:0]  snoop_cd_data,
    output                   snoop_cd_last,
    output                   snoop_cd_valid,
    input                    snoop_cd_ready
);

    // FSM States
    localparam [3:0] 
        IDLE       = 4'h0,
        READ_REQ   = 4'h1,
        READ_WAIT  = 4'h2,
        WRITE_REQ  = 4'h4,
        WRITE_DATA = 4'h5,
        WRITE_RESP = 4'h6,
        AMO_WAIT   = 4'h8, // Wait for B and R for AMOs
        RESP_CPU   = 4'h7;

    reg [3:0] state, next_state;

    // Internal Latches
    reg [ADDR_WIDTH-1:0] stored_addr;
    reg [DATA_WIDTH-1:0] stored_data;
    reg [ID_WIDTH-1:0]   stored_id;
    reg [2:0]            stored_prot;
    reg [5:0]            stored_atop;
    reg                  is_lr;
    reg                  is_sc;
    reg                  is_atomic_amo;
    reg [DATA_WIDTH-1:0] mem_read_data;
    reg                  sc_success;
    
    // AMO Completion Flags
    reg                  amo_b_done;
    reg                  amo_r_done;

    // Control Signals
    wire is_lr_op  = (cpu_ar_valid && cpu_ar_user[0]);
    wire is_sc_op  = (cpu_aw_valid && cpu_aw_user[0]);
    wire is_amo_op = (cpu_aw_valid && cpu_aw_atop[5]); // Bit 5 is set for all AXI5 Atomics (1xxxxx)

    // Sequential Logic
    always @(posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
            stored_addr <= 32'h0;
            stored_data <= 32'h0;
            stored_id <= 4'h0;
            stored_prot <= 3'h0;
            stored_atop <= 6'h0;
            is_lr <= 1'b0;
            is_sc <= 1'b0;
            is_atomic_amo <= 1'b0;
            mem_read_data <= 32'h0;
            sc_success <= 1'b0;
            amo_b_done <= 1'b0;
            amo_r_done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Store LR.W information
            if (cpu_ar_valid && cpu_ar_ready && is_lr_op) begin
                stored_addr <= cpu_ar_addr;
                stored_id <= cpu_ar_id;
                stored_prot <= cpu_ar_prot;
                is_lr <= 1'b1;
                is_sc <= 1'b0;
                is_atomic_amo <= 1'b0;
            end
            
            // Store SC.W information
            if (cpu_aw_valid && cpu_aw_ready && is_sc_op) begin
                stored_addr <= cpu_aw_addr;
                stored_data <= cpu_w_data;
                stored_id <= cpu_aw_id;
                stored_prot <= cpu_aw_prot;
                is_sc <= 1'b1;
                is_lr <= 1'b0;
                is_atomic_amo <= 1'b0;
            end
            
            // Store AMO information
            if (cpu_aw_valid && cpu_aw_ready && is_amo_op) begin
                stored_addr <= cpu_aw_addr;
                stored_data <= cpu_w_data;
                stored_id <= cpu_aw_id;
                stored_prot <= cpu_aw_prot;
                stored_atop <= cpu_aw_atop;
                is_atomic_amo <= 1'b1;
                is_lr <= 1'b0;
                is_sc <= 1'b0;
                amo_b_done <= 1'b0;
                amo_r_done <= 1'b0;
            end
            
            // Capture Read Data (LR or AMO)
            if (mem_r_valid && mem_r_ready) begin
                mem_read_data <= mem_r_data;
                if (is_atomic_amo) amo_r_done <= 1'b1;
            end
            
            // Capture Write Response (SC or AMO)
            if (mem_b_valid && mem_b_ready) begin
                if (is_sc) begin
                    // Check for EXOKAY (2'b01) for SC success
                    if (mem_b_resp == 2'b01) sc_success <= 1'b1;
                    else sc_success <= 1'b0;
                end
                if (is_atomic_amo) amo_b_done <= 1'b1;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        
        case(state)
            IDLE: begin
                if (is_lr_op && cpu_ar_valid) next_state = READ_REQ;
                else if (is_sc_op && cpu_aw_valid) next_state = WRITE_REQ;
                else if (is_amo_op && cpu_aw_valid) next_state = WRITE_REQ;
            end
            
            READ_REQ: begin
                if (mem_ar_ready) next_state = READ_WAIT;
            end
            
            READ_WAIT: begin
                if (mem_r_valid) next_state = RESP_CPU;
            end
            
            WRITE_REQ: begin
                if (mem_aw_ready) next_state = WRITE_DATA;
            end
            
            WRITE_DATA: begin
                if (mem_w_ready) begin
                    if (is_atomic_amo) next_state = AMO_WAIT;
                    else next_state = WRITE_RESP;
                end
            end
            
            WRITE_RESP: begin // For SC
                if (mem_b_valid) next_state = RESP_CPU;
            end
            
            AMO_WAIT: begin // For AMO (Wait for both B and R)
                // We need both B and R to complete.
                // Note: The actual transition happens when the LAST one arrives.
                // Since we latch done flags, we check if (done || valid) for both.
                if ((amo_b_done || mem_b_valid) && (amo_r_done || mem_r_valid)) 
                    next_state = RESP_CPU;
            end
            
            RESP_CPU: begin
                if ((is_lr || is_atomic_amo) && cpu_r_ready) next_state = IDLE;
                else if (is_sc && cpu_b_ready) next_state = IDLE;
            end
        endcase
    end

    // Output Assignments
    
    // AR Channel (LR only)
    assign mem_ar_addr  = (state == READ_REQ) ? stored_addr : 32'h0;
    assign mem_ar_prot  = (state == READ_REQ) ? stored_prot : 3'h0;
    assign mem_ar_id    = (state == READ_REQ) ? stored_id : 4'h0;
    assign mem_ar_lock  = (state == READ_REQ); // LR uses Exclusive Access (AxLOCK=1)
    assign mem_ar_valid = (state == READ_REQ);
    assign cpu_ar_ready = (state == IDLE) && (is_lr_op);
    
    // R Channel (Return Data to CPU)
    assign cpu_r_data  = (is_sc) ? (sc_success ? 32'h0 : 32'h1) : mem_read_data;
    assign cpu_r_resp  = 2'b00; // OKAY
    assign cpu_r_id    = stored_id;
    assign cpu_r_last  = 1'b1;
    assign cpu_r_valid = (state == RESP_CPU) && (is_lr || is_atomic_amo);
    assign mem_r_ready = (state == READ_WAIT) || (state == AMO_WAIT);
    
    // AW Channel (SC and AMO)
    assign mem_aw_addr  = (state == WRITE_REQ) ? stored_addr : 32'h0;
    assign mem_aw_prot  = (state == WRITE_REQ) ? stored_prot : 3'h0;
    assign mem_aw_id    = (state == WRITE_REQ) ? stored_id : 4'h0;
    assign mem_aw_atop  = (state == WRITE_REQ && is_atomic_amo) ? stored_atop : 6'h0;
    assign mem_aw_lock  = (state == WRITE_REQ) && is_sc; // SC uses Exclusive Access
    assign mem_aw_valid = (state == WRITE_REQ);
    assign cpu_aw_ready = (state == IDLE) && (is_sc_op || is_amo_op);
    
    // W Channel
    // Invert data for AtomicLoad CLR (AMOAND)
    // AtomicLoad CLR (0x21/100001) clears bits that are 1 in data.
    // AMOAND wants result = mem & data.
    // mem & data == mem & ~(~data).
    // So if we send ~data to CLR, it does mem & ~(~data) = mem & data.
    wire [DATA_WIDTH-1:0] wdata_out = (is_atomic_amo && stored_atop == 6'b100001) ? ~stored_data : stored_data;
    
    assign mem_w_data  = (state == WRITE_DATA) ? wdata_out : 32'h0;
    assign mem_w_strb  = 4'hF;
    assign mem_w_last  = 1'b1;
    assign mem_w_valid = (state == WRITE_DATA);
    assign cpu_w_ready = 1'b0; // We captured data in IDLE
    
    // B Channel
    assign cpu_b_resp  = (is_sc) ? (sc_success ? 2'b00 : 2'b01) : 2'b00; // Invert logic: 0=Success/OKAY for CPU? 
    // Wait, RISC-V SC: rd=0 for success, rd=1 for failure.
    // AXI: EXOKAY(01)=Success, OKAY(00)=Failure (for exclusive).
    // So if sc_success (EXOKAY received), we return 0 (Success). Else 1.
    
    assign cpu_b_id    = stored_id;
    assign cpu_b_last  = 1'b1;
    assign cpu_b_valid = (state == RESP_CPU) && is_sc; // Optional, if CPU expects B response
    assign mem_b_ready = (state == WRITE_RESP) || (state == AMO_WAIT);
    
    // Snoop Channel Assignments (Pass-through or Ignore)
    assign snoop_ac_ready = 1'b1;
    assign snoop_cr_resp  = 4'b0000;
    assign snoop_cr_valid = snoop_ac_valid;
    assign snoop_cd_data  = 32'h0;
    assign snoop_cd_last  = 1'b1;
    assign snoop_cd_valid = 1'b0;



endmodule