`timescale 1ns/1ps

module atomic_wrapper (
    input clk, rst_n,
    
    // From pipeline (E stage)
    input E_AtomicOp,
    input [4:0] E_atomic_funct5,
    input E_atomic_aq, E_atomic_rl,
    input [31:0] E_addr,
    input [31:0] E_RD1,     // rs1 data
    input [31:0] E_RD2,     // rs2 data
    
    // To pipeline
    output wire E_atomic_done,
    output wire [31:0] E_atomic_rd,
    output wire atomic_stall,
    
    // ACE/AXI Bus Signals (tie-off for now)
    output wire m_ARVALID, m_AWVALID, m_WVALID,
    input wire m_ARREADY, m_AWREADY, m_WREADY, m_RVALID, m_BVALID,
    // ... (other ACE/AXI signals omitted for brevity)
    output wire [31:0] m_ARADDR, m_AWADDR, m_WDATA,
    input wire [31:0] m_RDATA,
    input wire m_RLAST, m_WLAST
);
    
    // Internal state machine signals
    reg start, busy;
    wire ready;
    
    // Simplified ready signal (always ready if not busy)
    assign ready = ~busy;
    
    // ===== HANDSHAKE LOGIC: start/busy/valid_input/valid_output =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start <= 0;
            busy <= 0;
        end else begin
            // Start atomic when E_AtomicOp is high, unit is ready, and not busy
            if (E_AtomicOp && ready && ~busy) begin
                start <= 1;
                busy <= 1;
            end else begin
                start <= 0;
            end
            
            // Clear busy when atomic unit signals done
            if (E_atomic_done) begin
                busy <= 0;
            end
        end
    end
    
    // Stall pipeline while atomic is busy and not done
    assign atomic_stall = E_AtomicOp & busy & ~E_atomic_done;
    
    // ===== INSTANTIATE ATOMIC UNIT =====
    atomic_unit_ace atomic_unit_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Handshake signals
        .valid_input(start),
        .ready(ready),
        .valid_output(E_atomic_done),
        
        // Input data
        .funct5(E_atomic_funct5),
        .aq(E_atomic_aq),
        .rl(E_atomic_rl),
        .addr(E_addr),
        .rs1_data(E_RD1),
        .rs2_data(E_RD2),
        
        // Output
        .rd_value(E_atomic_rd),
        
        // ACE/AXI Bus (tie-off for now)
        .m_ARVALID(m_ARVALID),
        .m_ARREADY(m_ARREADY),
        .m_ARADDR(m_ARADDR),
        .m_AWVALID(m_AWVALID),
        .m_AWREADY(m_AWREADY),
        .m_AWADDR(m_AWADDR),
        .m_WVALID(m_WVALID),
        .m_WREADY(m_WREADY),
        .m_WDATA(m_WDATA),
        .m_RVALID(m_RVALID),
        .m_RDATA(m_RDATA),
        .m_RLAST(m_RLAST),
        .m_BVALID(m_BVALID),
        .m_WLAST(m_WLAST)
    );
    
endmodule
