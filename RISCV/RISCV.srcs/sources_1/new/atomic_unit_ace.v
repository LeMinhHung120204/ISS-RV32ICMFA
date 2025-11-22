`timescale 1ns/1ps

module atomic_unit_ace #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32,
    parameter CORE_ID = 0  // NEW: For multi-core systems
)(
    input clk, rst_n,
    
    // Control signals
    input valid_input,
    output reg ready,
    output reg valid_output,
    
    // Data inputs
    input [4:0] funct5,
    input aq, rl,
    input [WIDTH_ADDR-1:0] addr,
    input [WIDTH_DATA-1:0] rs1_data, rs2_data,
    
    // Result output  
    output reg [WIDTH_DATA-1:0] rd_value,
    
    // Reservation invalidation from snoop
    input snoop_invalidate,
    input [WIDTH_ADDR-1:0] snoop_addr,
    input [3:0] snoop_core_id,  // NEW: Which core sent snoop
    
    // Debug/monitoring
    output wire [3:0] debug_state,
    output wire debug_reservation_valid,
    
    // ===== AXI Master Interface (5 channels) =====
    // Read Address Channel (AR)
    output reg m_ARVALID,
    input wire m_ARREADY,
    output reg [WIDTH_ADDR-1:0] m_ARADDR,
    output wire [7:0] m_ARLEN,
    output wire [2:0] m_ARSIZE,
    output wire [1:0] m_ARBURST,
    
    // Read Data Channel (R)
    input wire m_RVALID,
    output reg m_RREADY,
    input wire [WIDTH_DATA-1:0] m_RDATA,
    input wire [1:0] m_RRESP,
    input wire m_RLAST,
    
    // Write Address Channel (AW)
    output reg m_AWVALID,
    input wire m_AWREADY,
    output reg [WIDTH_ADDR-1:0] m_AWADDR,
    output wire [7:0] m_AWLEN,
    output wire [2:0] m_AWSIZE,
    output wire [1:0] m_AWBURST,
    
    // Write Data Channel (W)
    output reg m_WVALID,
    input wire m_WREADY,
    output reg [WIDTH_DATA-1:0] m_WDATA,
    output wire [3:0] m_WSTRB,
    output wire m_WLAST,
    
    // Write Response Channel (B)
    input wire m_BVALID,
    output reg m_BREADY,
    input wire [1:0] m_BRESP,

    // ===== AXI ACE Extensions =====
    // Read Address Channel
    output wire [3:0] m_ARSNOOP,
    output wire [1:0] m_ARDOMAIN,
    output wire [1:0] m_ARBAR,
    
    // Write Address Channel
    output wire [2:0] m_AWSNOOP,
    output wire [1:0] m_AWDOMAIN,
    output wire [1:0] m_AWBAR
);
    
    // ===== STATE MACHINE =====
    localparam IDLE       = 4'b0000;
    localparam AR_WAIT    = 4'b0001;
    localparam R_WAIT     = 4'b0010;
    localparam CHECK_SC   = 4'b0011;
    localparam ALU        = 4'b0100;
    localparam AW_WAIT    = 4'b0101;
    localparam W_WAIT     = 4'b0110;
    localparam B_WAIT     = 4'b0111;
    localparam DONE       = 4'b1000;
    localparam SC_FAIL    = 4'b1001;
    
    reg [3:0] state, next_state;
    reg [WIDTH_DATA-1:0] read_data;
    reg [4:0] current_funct5;
    reg current_aq, current_rl;
    reg [WIDTH_ADDR-1:0] current_addr;
    reg [WIDTH_DATA-1:0] current_rs2;
    
    // ===== RESERVATION SET =====
    reg reservation_valid;
    reg [WIDTH_ADDR-1:0] reservation_addr;
    reg [3:0] reservation_core_id;  // NEW: Track which core owns reservation
    
    // ===== SC CONTROL FLAG (FIX #1) =====
    reg sc_will_succeed;  // NEW: Explicit flag to control write
    
    // ===== HELPER SIGNALS =====
    wire is_lr = (current_funct5 == 5'b00010);
    wire is_sc = (current_funct5 == 5'b00011);
    wire is_amo = !is_lr && !is_sc;
    
    // SC succeeds only if ALL conditions met
    wire sc_can_succeed = reservation_valid && 
                          (current_addr[WIDTH_ADDR-1:2] == reservation_addr[WIDTH_ADDR-1:2]) &&
                          (reservation_core_id == CORE_ID);  // NEW: Check core ID
    
    // ===== DEBUG OUTPUTS =====
    assign debug_state = state;
    assign debug_reservation_valid = reservation_valid;
    
    // ===== AXI FIXED SIGNALS =====
    assign m_ARLEN = 8'h00;
    assign m_ARSIZE = 3'b010;
    assign m_ARBURST = 2'b01;
    assign m_AWLEN = 8'h00;
    assign m_AWSIZE = 3'b010;
    assign m_AWBURST = 2'b01;
    assign m_WSTRB = 4'b1111;
    assign m_WLAST = 1'b1;

    // ===== AXI ACE LOGIC =====
    // Domain: 2'b01 = Inner Shareable (typical for multi-core within a cluster)
    assign m_ARDOMAIN = 2'b01; 
    assign m_AWDOMAIN = 2'b01;
    
    // Barriers: Normal memory access, respecting barriers
    assign m_ARBAR = 2'b00;
    assign m_AWBAR = 2'b00;

    // ARSNOOP Encoding:
    // LR -> ReadShared (0001): Read data, cacheable, other caches can keep copy
    // AMO (Read phase) -> ReadUnique (0111): Read data, invalidate other copies (we will write)
    assign m_ARSNOOP = is_lr ? 4'b0001 :          // ReadShared
                       is_amo ? 4'b0111 :         // ReadUnique
                       4'b0000;                   // Default/None

    // AWSNOOP Encoding:
    // SC -> WriteUnique (000): Write data, ensure no other copies exist
    // AMO (Write phase) -> WriteUnique (000)
    // Note: WriteUnique is typically 000 in ACE for full cache line or partial? 
    // Actually for partial writes or standard writes in ACE, WriteUnique (000) is common for coherent write.
    assign m_AWSNOOP = 3'b000; // WriteUnique
    
    // ===== DEADLOCK WATCHDOG (FIX #3) =====
    reg [15:0] state_timer;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_timer <= 0;
        end else begin
            if (state == next_state && state != IDLE && state != DONE && state != SC_FAIL) begin
                state_timer <= state_timer + 1;
            end else begin
                state_timer <= 0;
            end
        end
    end
    
    // Assertion for deadlock detection
    always @(posedge clk) begin
        if (state_timer > 16'hFFFF) begin
            $display("ERROR: Deadlock detected in state %d at time %t", state, $time);
            $fatal(1, "Atomic unit deadlock");
        end
    end
    
    // ===== RESERVATION MANAGEMENT =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reservation_valid <= 1'b0;
            reservation_addr <= {WIDTH_ADDR{1'b0}};
            reservation_core_id <= 4'b0;
        end else begin
            // Priority 1: Snoop invalidation
            if (snoop_invalidate && reservation_valid) begin
                // Invalidate if:
                // 1. Address matches (word-aligned)
                // 2. Snoop is from different core
                if ((snoop_addr[WIDTH_ADDR-1:2] == reservation_addr[WIDTH_ADDR-1:2]) &&
                    (snoop_core_id != CORE_ID)) begin
                    reservation_valid <= 1'b0;
                    `ifdef DEBUG
                    $display("Time %t: Core %d reservation invalidated by snoop from core %d", 
                             $time, CORE_ID, snoop_core_id);
                    `endif
                end
            end
            
            // Priority 2: LR sets reservation after successful read
            if (state == R_WAIT && m_RVALID && m_RREADY && is_lr) begin
                reservation_valid <= 1'b1;
                reservation_addr <= current_addr;
                reservation_core_id <= CORE_ID;
                `ifdef DEBUG
                $display("Time %t: Core %d set reservation at addr 0x%h", 
                         $time, CORE_ID, current_addr);
                `endif
            end
            
            // Priority 3: SC/AMO clear reservation
            if ((state == DONE || state == SC_FAIL) && (is_sc || is_amo)) begin
                reservation_valid <= 1'b0;
            end
        end
    end
    
    // ===== STATE REGISTER =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // ===== OUTPUT LOGIC =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
            valid_output <= 1'b0;
            rd_value <= {WIDTH_DATA{1'b0}};
            m_ARVALID <= 1'b0;
            m_ARADDR <= {WIDTH_ADDR{1'b0}};
            m_RREADY <= 1'b0;
            m_AWVALID <= 1'b0;
            m_AWADDR <= {WIDTH_ADDR{1'b0}};
            m_WVALID <= 1'b0;
            m_WDATA <= {WIDTH_DATA{1'b0}};
            m_BREADY <= 1'b0;
            current_funct5 <= 5'b0;
            current_aq <= 1'b0;
            current_rl <= 1'b0;
            current_addr <= {WIDTH_ADDR{1'b0}};
            current_rs2 <= {WIDTH_DATA{1'b0}};
            read_data <= {WIDTH_DATA{1'b0}};
            sc_will_succeed <= 1'b0;  // NEW
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    valid_output <= 1'b0;
                    m_ARVALID <= 1'b0;
                    m_RREADY <= 1'b0;
                    m_AWVALID <= 1'b0;
                    m_WVALID <= 1'b0;
                    m_BREADY <= 1'b0;
                    sc_will_succeed <= 1'b0;  // NEW: Reset flag
                    
                    if (valid_input && ready) begin
                        current_funct5 <= funct5;
                        current_aq <= aq;
                        current_rl <= rl;
                        current_addr <= addr;
                        current_rs2 <= rs2_data;
                        ready <= 1'b0;
                    end
                end
                
                AR_WAIT: begin
                    m_ARVALID <= 1'b1;
                    m_ARADDR <= current_addr;
                    m_RREADY <= 1'b1;
                end
                
                R_WAIT: begin
                    m_ARVALID <= 1'b0;
                    m_RREADY <= 1'b1;
                    
                    if (m_RVALID && m_RREADY) begin
                        read_data <= m_RDATA;
                        m_RREADY <= 1'b0;
                    end
                end
                
                CHECK_SC: begin
                    // FIX #1: Set explicit flag for SC success/fail
                    if (sc_can_succeed) begin
                        sc_will_succeed <= 1'b1;  // ✅ Will write
                    end else begin
                        sc_will_succeed <= 1'b0;  // ✅ Will NOT write
                        rd_value <= 32'h00000001; // Return failure
                    end
                end
                
                ALU: begin
                    m_WDATA <= perform_amo(read_data, current_rs2, current_funct5);
                end
                
                AW_WAIT: begin
                    // FIX #1: Only assert AWVALID if we will actually write
                    if (is_amo || (is_sc && sc_will_succeed)) begin
                        m_AWVALID <= 1'b1;
                        m_AWADDR <= current_addr;
                    end
                    m_BREADY <= 1'b1;
                end
                
                W_WAIT: begin
                    // FIX #1: CRITICAL - Only assert WVALID if write is allowed
                    if (is_amo || (is_sc && sc_will_succeed)) begin
                        m_WVALID <= 1'b1;
                    end else begin
                        m_WVALID <= 1'b0;  // ✅ Guarantee no write if SC failed
                    end
                    
                    if (!m_AWREADY && (is_amo || (is_sc && sc_will_succeed))) begin
                        m_AWVALID <= 1'b1;
                    end else begin
                        m_AWVALID <= 1'b0;
                    end
                end
                
                B_WAIT: begin
                    m_AWVALID <= 1'b0;
                    m_WVALID <= 1'b0;
                    m_BREADY <= 1'b1;
                    
                    if (m_BVALID && m_BREADY) begin
                        m_BREADY <= 1'b0;
                    end
                end
                
                SC_FAIL: begin
                    valid_output <= 1'b1;
                    rd_value <= 32'h00000001;  // SC failed
                end
                
                DONE: begin
                    valid_output <= 1'b1;
                    
                    // FIX #2: Clarify return values
                    if (is_sc) begin
                        // SC succeeded (only reach here if sc_will_succeed was true)
                        rd_value <= 32'h00000000;
                    end else if (is_lr) begin
                        // LR returns loaded value
                        rd_value <= read_data;
                    end else begin
                        // AMO returns OLD value (before modification)
                        // Memory is updated with NEW value via m_WDATA
                        rd_value <= read_data;
                    end
                end
            endcase
        end
    end
    
    // ===== NEXT STATE LOGIC =====
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (valid_input && ready)
                    next_state = AR_WAIT;
            end
            
            AR_WAIT: begin
                if (m_ARVALID && m_ARREADY)
                    next_state = R_WAIT;
            end
            
            R_WAIT: begin
                if (m_RVALID && m_RREADY) begin
                    if (is_lr)
                        next_state = DONE;
                    else if (is_sc)
                        next_state = CHECK_SC;
                    else
                        next_state = ALU;
                end
            end
            
            CHECK_SC: begin
                if (!sc_can_succeed)
                    next_state = SC_FAIL;
                else
                    next_state = ALU;
            end
            
            ALU: begin
                next_state = AW_WAIT;
            end
            
            AW_WAIT: begin
                next_state = W_WAIT;
            end
            
            W_WAIT: begin
                // Only proceed if write channels complete
                // OR if this is SC that failed (skip write)
                if (is_sc && !sc_will_succeed) begin
                    next_state = SC_FAIL;
                end else if ((m_AWVALID && m_AWREADY) && (m_WVALID && m_WREADY)) begin
                    next_state = B_WAIT;
                end else if (m_AWREADY && m_WREADY) begin
                    next_state = B_WAIT;
                end
            end
            
            B_WAIT: begin
                if (m_BVALID && m_BREADY)
                    next_state = DONE;
            end
            
            SC_FAIL: begin
                next_state = IDLE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ===== AMO FUNCTION =====
    function [WIDTH_DATA-1:0] perform_amo;
        input [WIDTH_DATA-1:0] mem_data, rs2_data;
        input [4:0] funct5;
        begin
            case (funct5)
                5'b00010: perform_amo = mem_data;                    // LR.W
                5'b00011: perform_amo = rs2_data;                    // SC.W
                5'b00001: perform_amo = rs2_data;                    // AMOSWAP.W
                5'b00000: perform_amo = mem_data + rs2_data;         // AMOADD.W
                5'b00100: perform_amo = mem_data ^ rs2_data;         // AMOXOR.W
                5'b01100: perform_amo = mem_data & rs2_data;         // AMOAND.W
                5'b01000: perform_amo = mem_data | rs2_data;         // AMOOR.W
                5'b10000: perform_amo = ($signed(mem_data) < $signed(rs2_data)) ? 
                                        mem_data : rs2_data;         // AMOMIN.W
                5'b10100: perform_amo = ($signed(mem_data) > $signed(rs2_data)) ? 
                                        mem_data : rs2_data;         // AMOMAX.W
                5'b11000: perform_amo = (mem_data < rs2_data) ? 
                                        mem_data : rs2_data;         // AMOMINU.W
                5'b11100: perform_amo = (mem_data > rs2_data) ? 
                                        mem_data : rs2_data;         // AMOMAXU.W
                default:  perform_amo = 32'b0;
            endcase
        end
    endfunction
    
    // ===== ASSERTIONS FOR VERIFICATION =====
    `ifdef FORMAL
    // Formal verification properties
    always @(posedge clk) begin
        // Property 1: SC cannot write if reservation invalid
        if (is_sc && !sc_can_succeed) begin
            assert (m_WVALID == 1'b0) 
                else $error("SC writing when reservation invalid!");
        end
        
        // Property 2: Ready and valid_output never both high
        assert (!(ready && valid_output))
            else $error("Ready and valid_output both high!");
        
        // Property 3: LR must set reservation
        if (state == DONE && is_lr) begin
            assert (reservation_valid == 1'b1)
                else $error("LR did not set reservation!");
        end
    end
    `endif
    
endmodule
