`timescale 1ns / 1ps

module unit_atomic #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter STRB_WIDTH = 4,
    parameter NUM_CORES  = 4,
    parameter USE_LOCAL_ALU = 1  // 1: Use local ALU + exclusive lock (portable), 0: Rely on ATOP from memory
) (
    input  clk,
    input  rstn,
    
    // LR (Load-Reserved) read address channel
    input  [ADDR_WIDTH-1:0]  cpu_ar_addr,
    input  [2:0]             cpu_ar_prot,
    input  [ID_WIDTH-1:0]    cpu_ar_id,
    input  [3:0]             cpu_ar_user,  // [3]=aq, [2]=rl, [1]=is_sc, [0]=is_lr
    input                    cpu_ar_lock,
    input                    cpu_ar_valid,
    output reg               cpu_ar_ready,
    
    // Read data: Return reserved data (LR), old value (AMO), or SC result (0/1)
    output [DATA_WIDTH-1:0]  cpu_r_data,
    output [1:0]             cpu_r_resp,
    output [ID_WIDTH-1:0]    cpu_r_id,
    output                   cpu_r_last,
    output reg               cpu_r_valid,
    input                    cpu_r_ready,
    
    // SC/AMO write address channel
    input  [ADDR_WIDTH-1:0]  cpu_aw_addr,
    input  [2:0]             cpu_aw_prot,
    input  [ID_WIDTH-1:0]    cpu_aw_id,
    input  [5:0]             cpu_aw_atop,   // AXI atomic operation type (if USE_LOCAL_ALU=0)
    input  [3:0]             cpu_aw_user,   // [3]=aq, [2]=rl, [1]=is_sc, [0]=unused
    input                    cpu_aw_lock,
    input                    cpu_aw_valid,
    output reg               cpu_aw_ready,
    
    // Write data: Operand for SC/AMO operations
    input  [DATA_WIDTH-1:0]  cpu_w_data,
    input  [STRB_WIDTH-1:0]  cpu_w_strb,
    input                    cpu_w_last,
    input                    cpu_w_valid,
    output reg               cpu_w_ready,
    
    // Write response (not used for LR/SC/AMO results, all via R channel)
    output [1:0]             cpu_b_resp,
    output [ID_WIDTH-1:0]    cpu_b_id,
    output                   cpu_b_last,
    output reg               cpu_b_valid,
    input                    cpu_b_ready,
    
    // Memory interface - Read Address Channel
    output [ADDR_WIDTH-1:0]  mem_ar_addr,
    output [2:0]             mem_ar_prot,
    output [ID_WIDTH-1:0]    mem_ar_id,
    output                   mem_ar_lock,   // Set for exclusive LR or AMO read phase
    output reg               mem_ar_valid,
    input                    mem_ar_ready,
    
    // Memory interface - Read Data Channel
    input  [DATA_WIDTH-1:0]  mem_r_data,
    input  [1:0]             mem_r_resp,
    input  [ID_WIDTH-1:0]    mem_r_id,
    input                    mem_r_last,
    input                    mem_r_valid,
    output reg               mem_r_ready,
    
    // Memory interface - Write Address Channel
    output [ADDR_WIDTH-1:0]  mem_aw_addr,
    output [2:0]             mem_aw_prot,
    output [ID_WIDTH-1:0]    mem_aw_id,
    output [5:0]             mem_aw_atop,   // Only used if USE_LOCAL_ALU=0 (ATOP mode)
    output                   mem_aw_lock,   // Set for exclusive SC or AMO write phase
    output reg               mem_aw_valid,
    input                    mem_aw_ready,
    
    // Memory interface - Write Data Channel
    output [DATA_WIDTH-1:0]  mem_w_data,
    output [STRB_WIDTH-1:0]  mem_w_strb,
    output                   mem_w_last,
    output reg               mem_w_valid,
    input                    mem_w_ready,
    
    // Memory interface - Write Response Channel
    input  [1:0]             mem_b_resp,
    input  [ID_WIDTH-1:0]    mem_b_id,
    input                    mem_b_last,
    input                    mem_b_valid,
    output reg               mem_b_ready,
    
    // ACE Snoop channels for cache coherency
    input  [ADDR_WIDTH-1:0]  snoop_ac_addr,
    input  [3:0]             snoop_ac_snoop,
    input                    snoop_ac_valid,
    output                   snoop_ac_ready,
    
    output [3:0]             snoop_cr_resp,
    output                   snoop_cr_valid,
    input                    snoop_cr_ready,
    
    output [DATA_WIDTH-1:0]  snoop_cd_data,
    output                   snoop_cd_last,
    output                   snoop_cd_valid,
    input                    snoop_cd_ready
);

    // FSM States for atomic operation sequencing
    localparam [3:0] 
        IDLE        = 4'h0,  // Waiting for new request
        LR_REQ      = 4'h1,  // LR: sending read request to memory
        LR_WAIT     = 4'h2,  // LR: waiting for read response
        AMO_READ    = 4'h3,  // AMO: sending read request
        AMO_WAIT    = 4'h4,  // AMO: waiting for read response
        ALU_COMP    = 4'h5,  // AMO: computing result in local ALU
        SC_WRITE    = 4'h6,  // SC: sending exclusive write request
        AMO_WRITE   = 4'h7,  // AMO: sending write request with computed result
        WRITE_DATA  = 4'h8,  // Sending write data to memory
        WRITE_RESP  = 4'h9,  // Waiting for write response from memory
        RESP_CPU    = 4'hA;  // Sending result back to CPU

    reg [3:0] state, next_state;

    // Per-core reservation state for LR/SC synchronization
    reg [ADDR_WIDTH-1:0] reserved_addr [NUM_CORES-1:0];  // Address reserved by LR for each core
    reg                  lr_valid [NUM_CORES-1:0];       // Whether reservation is valid for each core
    reg                  aq_pending [NUM_CORES-1:0];     // Acquire bit pending (block next op until complete)
    reg                  rl_pending [NUM_CORES-1:0];     // Release bit pending (wait for previous op)

    // Transaction storage during multi-cycle operations
    reg [ADDR_WIDTH-1:0] stored_addr;
    reg [DATA_WIDTH-1:0] stored_data;      // Operand/write data
    reg [ID_WIDTH-1:0]   stored_id;
    reg [ID_WIDTH-1:0]   core_idx;         // Core ID of current transaction
    reg [2:0]            stored_prot;
    reg [5:0]            stored_atop;
    reg [3:0]            stored_user;      // [3]=aq, [2]=rl, [1]=is_sc, [0]=is_lr
    
    // Operation type flags
    reg                  is_lr_op;
    reg                  is_sc_op;
    reg                  is_amo_op;
    
    // Intermediate values during operation
    reg [DATA_WIDTH-1:0] mem_read_data;    // Value read from memory
    reg [DATA_WIDTH-1:0] amo_result;       // Result computed by ALU
    reg                  sc_success;       // SC succeeded (1) or failed (0)
    
    // Decode user bits to get operation information
    wire                 aq_bit = stored_user[3];  // Acquire: no later ops before this
    wire                 rl_bit = stored_user[2];  // Release: this op waits for earlier ops
    wire                 is_sc  = stored_user[1];  // Store-Conditional flag
    wire                 is_lr  = stored_user[0];  // Load-Reserved flag

    // Local ALU: Performs atomic read-modify-write operations
    // Returns old value (register gets old value per RISC-V spec)
    function [DATA_WIDTH-1:0] amo_alu;
        input [5:0] atop;
        input [DATA_WIDTH-1:0] old_val, new_val;
        begin
            case (atop)
                6'b100000: amo_alu = old_val + new_val;                                      // AMOADD
                6'b110000: amo_alu = new_val;                                                // AMOSWAP
                6'b100001: amo_alu = old_val & new_val;                                      // AMOAND
                6'b100011: amo_alu = old_val | new_val;                                      // AMOOR
                6'b100010: amo_alu = old_val ^ new_val;                                      // AMOXOR
                6'b100101: amo_alu = ($signed(old_val) < $signed(new_val)) ? old_val : new_val;  // AMOMIN (signed)
                6'b100100: amo_alu = ($signed(old_val) > $signed(new_val)) ? old_val : new_val;  // AMOMAX (signed)
                6'b100111: amo_alu = (old_val < new_val) ? old_val : new_val;                // AMOMINU (unsigned)
                6'b100110: amo_alu = (old_val > new_val) ? old_val : new_val;                // AMOMAXU (unsigned)
                default: amo_alu = new_val;
            endcase
        end
    endfunction

    // [PR #65 FIX]: Consolidated all state machine and reservation array updates
    // into SINGLE always block to eliminate multiple drivers issue
    integer i;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            stored_addr <= {ADDR_WIDTH{1'b0}};
            stored_data <= {DATA_WIDTH{1'b0}};
            stored_id <= 4'h0;
            core_idx <= 4'h0;
            stored_prot <= 3'h0;
            stored_atop <= 6'h0;
            stored_user <= 4'h0;
            is_lr_op <= 1'b0;
            is_sc_op <= 1'b0;
            is_amo_op <= 1'b0;
            mem_read_data <= {DATA_WIDTH{1'b0}};
            amo_result <= {DATA_WIDTH{1'b0}};
            sc_success <= 1'b0;
            // Initialize per-core reservation arrays
            for (i = 0; i < NUM_CORES; i = i + 1) begin
                lr_valid[i] <= 1'b0;
                reserved_addr[i] <= {ADDR_WIDTH{1'b0}};
                aq_pending[i] <= 1'b0;
                rl_pending[i] <= 1'b0;
            end
        end else begin
            state <= next_state;

            // Capture LR transaction: Load with reservation
            // Sets exclusive access flag on memory, stores address for future SC validation
            if (cpu_ar_valid && cpu_ar_ready && cpu_ar_user[0]) begin
                stored_addr <= cpu_ar_addr;
                stored_id <= cpu_ar_id;
                core_idx <= cpu_ar_id;
                stored_prot <= cpu_ar_prot;
                stored_user <= cpu_ar_user;
                is_lr_op <= 1'b1;
                is_sc_op <= 1'b0;
                is_amo_op <= 1'b0;
                // Set aq_pending if acquire bit is set
                if (cpu_ar_user[3]) begin
                    aq_pending[cpu_ar_id] <= 1'b1;
                end
                // [PR #65 FIX] Set rl_pending if release bit is set
                if (cpu_ar_user[2]) begin
                    rl_pending[cpu_ar_id] <= 1'b1;
                end
            end

            // Capture SC transaction: Store-Conditional
            // Only succeeds if reservation still valid at same address
            if (cpu_aw_valid && cpu_aw_ready && cpu_aw_user[1]) begin
                stored_addr <= cpu_aw_addr;
                stored_data <= cpu_w_data;
                stored_id <= cpu_aw_id;
                core_idx <= cpu_aw_id;
                stored_prot <= cpu_aw_prot;
                stored_user <= cpu_aw_user;
                is_sc_op <= 1'b1;
                is_lr_op <= 1'b0;
                is_amo_op <= 1'b0;
                // Set aq_pending if acquire bit is set
                if (cpu_aw_user[3]) begin
                    aq_pending[cpu_aw_id] <= 1'b1;
                end
                // [PR #65 FIX] Set rl_pending if release bit is set
                if (cpu_aw_user[2]) begin
                    rl_pending[cpu_aw_id] <= 1'b1;
                end
            end

            // Capture AMO transaction: Atomic Memory Operation
            // Read old value, compute result using ALU, write back, return old value to register
            if (cpu_aw_valid && cpu_aw_ready && ~cpu_aw_user[1]) begin
                stored_addr <= cpu_aw_addr;
                stored_data <= cpu_w_data;
                stored_id <= cpu_aw_id;
                core_idx <= cpu_aw_id;
                stored_prot <= cpu_aw_prot;
                stored_atop <= cpu_aw_atop;
                stored_user <= cpu_aw_user;
                is_amo_op <= 1'b1;
                is_lr_op <= 1'b0;
                is_sc_op <= 1'b0;
                // Set aq_pending if acquire bit is set
                if (cpu_aw_user[3]) begin
                    aq_pending[cpu_aw_id] <= 1'b1;
                end
                // [PR #65 FIX] Set rl_pending if release bit is set
                if (cpu_aw_user[2]) begin
                    rl_pending[cpu_aw_id] <= 1'b1;
                end
            end

            // Capture read response: Store old value for AMO ALU computation or return to CPU
            if (mem_r_valid && mem_r_ready) begin
                mem_read_data <= mem_r_data;
                
                // After LR succeeds (OKAY response), set reservation for this core
                if (is_lr_op && (mem_r_resp == 2'b00)) begin
                    lr_valid[core_idx] <= 1'b1;
                    reserved_addr[core_idx] <= stored_addr;
                end
            end

            // Capture write response: Evaluate SC success
            // SC succeeds only if: (1) reservation valid, (2) addresses match, (3) memory returns EXOKAY
            if (mem_b_valid && mem_b_ready) begin
                if (is_sc_op) begin
                    if (lr_valid[core_idx] && (reserved_addr[core_idx] == stored_addr) && (mem_b_resp == 2'b01)) begin
                        sc_success <= 1'b1;  // Success: return 0 to register
                        lr_valid[core_idx] <= 1'b0;  // Clear reservation after SC attempt
                    end else begin
                        sc_success <= 1'b0;  // Failure: return 1 to register
                    end
                end
                
                // [PR #65 FIX] Clear aq_pending and rl_pending after operation completes
                if (aq_pending[core_idx]) begin
                    aq_pending[core_idx] <= 1'b0;
                end
                if (rl_pending[core_idx]) begin
                    rl_pending[core_idx] <= 1'b0;
                end
            end

            // Handle snoop invalidation: ACE coherency invalidates reservation if address matches
            // Prevents SC from succeeding after another master wrote to reserved address
            if (snoop_ac_valid && snoop_ac_ready) begin
                for (i = 0; i < NUM_CORES; i = i + 1) begin
                    // [PR #65 FIX] Changed mask from [31:3] to [31:2] for correct 4-byte word granularity
                    if (reserved_addr[i][ADDR_WIDTH-1:2] == snoop_ac_addr[ADDR_WIDTH-1:2]) begin
                        lr_valid[i] <= 1'b0;  // Invalidate reservation
                    end
                end
            end

            // ALU computation phase: Compute result for AMO operation
            // Result = f(old_value, operand) where f is ADD, XOR, OR, AND, MIN, MAX, SWAP, etc.
            if (state == ALU_COMP) begin
                amo_result <= amo_alu(stored_atop, mem_read_data, stored_data);
            end
        end
    end

    // FSM next state logic: Determines state transitions based on handshake signals
    always @(*) begin
        next_state = state;

        case(state)
            IDLE: begin
                // Accept new LR if no release pending from previous core
                if (cpu_ar_valid && cpu_ar_user[0] && ~rl_pending[cpu_ar_id])
                    next_state = LR_REQ;
                // Accept new SC/AMO if no release pending
                else if (cpu_aw_valid && cpu_aw_user[1] && ~rl_pending[cpu_aw_id])
                    next_state = SC_WRITE;
                else if (cpu_aw_valid && ~cpu_aw_user[1] && ~rl_pending[cpu_aw_id])
                    next_state = (USE_LOCAL_ALU) ? AMO_READ : SC_WRITE;
            end

            // LR sequence: Request memory → wait for data → return to CPU
            LR_REQ: if (mem_ar_ready) next_state = LR_WAIT;
            LR_WAIT: if (mem_r_valid) next_state = RESP_CPU;

            // SC sequence: Write request → send data → wait response → return status to CPU
            SC_WRITE: if (mem_aw_ready) next_state = WRITE_DATA;

            // AMO sequence with local ALU: Read → wait → compute → write → send data → wait response → return old value
            AMO_READ: if (mem_ar_ready) next_state = AMO_WAIT;
            AMO_WAIT: if (mem_r_valid) next_state = ALU_COMP;
            ALU_COMP: next_state = AMO_WRITE;
            AMO_WRITE: if (mem_aw_ready) next_state = WRITE_DATA;

            // Common write completion path
            WRITE_DATA: if (mem_w_ready) next_state = WRITE_RESP;
            WRITE_RESP: if (mem_b_valid) next_state = RESP_CPU;

            // Return result to CPU and go back to IDLE
            RESP_CPU: if (cpu_r_ready) next_state = IDLE;
        endcase
    end

    // Memory Read Address Channel: Send address and control to memory
    assign mem_ar_addr  = (state == LR_REQ || state == AMO_READ) ? stored_addr : {ADDR_WIDTH{1'b0}};
    assign mem_ar_prot  = (state == LR_REQ || state == AMO_READ) ? stored_prot : 3'h0;
    assign mem_ar_id    = (state == LR_REQ || state == AMO_READ) ? stored_id : {ID_WIDTH{1'b0}};
    // Exclusive lock: LR uses lock to reserve address; AMO uses lock if using local ALU instead of ATOP
    assign mem_ar_lock  = (state == LR_REQ) ? 1'b1 : ((state == AMO_READ && USE_LOCAL_ALU) ? 1'b1 : 1'b0);
    
    always @(*) begin
        mem_ar_valid = 1'b0;
        // Send only if not blocked by acquire bit from previous operation
        if ((state == LR_REQ || state == AMO_READ) && ~aq_pending[core_idx]) mem_ar_valid = 1'b1;
    end

    // CPU Read Data: Returns LR data, old value (AMO), or SC result (0=success, 1=failure)
    assign cpu_r_data = (is_amo_op) ? mem_read_data : 
                        (is_sc_op) ? (sc_success ? 32'h0 : 32'h1) : 
                        mem_read_data;  // LR: return read data
    assign cpu_r_resp = 2'b00;
    assign cpu_r_id = stored_id;
    assign cpu_r_last = 1'b1;

    always @(*) begin
        cpu_r_valid = 1'b0;
        mem_r_ready = 1'b0;
        
        case(state)
            LR_WAIT: mem_r_ready = 1'b1;
            AMO_WAIT: mem_r_ready = 1'b1;
            RESP_CPU: cpu_r_valid = (is_lr_op || is_sc_op || is_amo_op) ? 1'b1 : 1'b0;
        endcase
    end

    // Memory Write Address Channel
    assign mem_aw_addr  = (state == SC_WRITE || state == AMO_WRITE) ? stored_addr : {ADDR_WIDTH{1'b0}};
    assign mem_aw_prot  = (state == SC_WRITE || state == AMO_WRITE) ? stored_prot : 3'h0;
    assign mem_aw_id    = (state == SC_WRITE || state == AMO_WRITE) ? stored_id : {ID_WIDTH{1'b0}};
    // ATOP encoding: Only used if USE_LOCAL_ALU=0 (memory handles AMO)
    assign mem_aw_atop  = ((state == AMO_WRITE) && ~USE_LOCAL_ALU) ? stored_atop : 6'h0;
    // Exclusive lock: SC uses lock for conditional store; AMO uses lock if local ALU mode
    assign mem_aw_lock  = ((state == SC_WRITE) ? 1'b1 : ((state == AMO_WRITE && USE_LOCAL_ALU) ? 1'b1 : 1'b0));

    always @(*) begin
        mem_aw_valid = 1'b0;
        // Send only if not blocked by acquire bit
        if ((state == SC_WRITE || state == AMO_WRITE) && ~aq_pending[core_idx]) mem_aw_valid = 1'b1;
    end

    // Memory Write Data: Send operand (SC) or computed result (AMO)
    assign mem_w_data = (state == WRITE_DATA) ? 
                        ((is_amo_op && USE_LOCAL_ALU) ? amo_result : stored_data) : {DATA_WIDTH{1'b0}};
    assign mem_w_strb = (state == WRITE_DATA) ? {STRB_WIDTH{1'b1}} : {STRB_WIDTH{1'b0}};
    assign mem_w_last = 1'b1;

    always @(*) begin
        mem_w_valid = (state == WRITE_DATA) ? 1'b1 : 1'b0;
        // CPU can send data when entering SC/AMO write phase
        cpu_w_ready = ((state == IDLE || state == SC_WRITE || state == AMO_READ) && cpu_aw_valid) ? 1'b1 : 1'b0;
    end

    // Write Response: Not used for atomic results (all results go via R channel)
    assign cpu_b_resp = 2'b00;
    assign cpu_b_id = stored_id;
    assign cpu_b_last = 1'b1;

    always @(*) begin
        cpu_b_valid = 1'b0;
        mem_b_ready = 1'b0;
        
        if (state == WRITE_RESP) begin
            mem_b_ready = 1'b1;
            cpu_b_valid = 1'b0;  // All atomic results returned via R channel
        end
    end

    // CPU Ready Signals: Each core checks its own aq/rl pending (not previous core's)
    // aq (acquire): This operation blocks later ops, so check aq_pending of incoming core
    // rl (release): This operation waits for earlier ops, so check rl_pending of incoming core
    always @(*) begin
        cpu_ar_ready = (state == IDLE && ~aq_pending[cpu_ar_id]) ? 1'b1 : 1'b0;
        cpu_aw_ready = (state == IDLE && ~rl_pending[cpu_aw_id]) ? 1'b1 : 1'b0;
    end

    // Snoop (ACE Coherency): Accept invalidation requests
    assign snoop_ac_ready = 1'b1;  // Always accept snoop
    assign snoop_cr_valid = 1'b0;  // No coherency response needed for atomics
    assign snoop_cd_valid = 1'b0;  // No snoop data return
    
    assign snoop_cr_resp = 4'b0000;
    assign snoop_cd_data = {DATA_WIDTH{1'b0}};
    assign snoop_cd_last = 1'b1;

endmodule
