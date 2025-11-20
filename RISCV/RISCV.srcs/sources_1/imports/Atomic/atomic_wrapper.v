`timescale 1ns/1ps

module atomic_wrapper #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32,
    parameter CORE_ID = 0
)(
    input clk, 
    input rst_n,
    
    // From pipeline (E stage)
    input E_AtomicOp,
    input [4:0] E_atomic_funct5,
    input E_atomic_aq, 
    input E_atomic_rl,
    input [WIDTH_ADDR-1:0] E_addr,
    input [WIDTH_DATA-1:0] E_RD1,
    input [WIDTH_DATA-1:0] E_RD2,
    
    // To pipeline
    output wire E_atomic_done,
    output wire [WIDTH_DATA-1:0] E_atomic_rd,
    output wire atomic_stall,
    
    // Snoop interface (can be tied off if not used)
    input snoop_valid,
    input [WIDTH_ADDR-1:0] snoop_addr,
    input [3:0] snoop_type,
    input [3:0] snoop_core_id,
    
    // Debug outputs
    output wire [3:0] debug_state,
    output wire debug_reservation_valid,
    
    // AXI Master - Read Address Channel
    output wire m_ARVALID,
    input wire m_ARREADY,
    output wire [WIDTH_ADDR-1:0] m_ARADDR,
    output wire [7:0] m_ARLEN,
    output wire [2:0] m_ARSIZE,
    output wire [1:0] m_ARBURST,
    
    // AXI Master - Read Data Channel
    input wire m_RVALID,
    output wire m_RREADY,
    input wire [WIDTH_DATA-1:0] m_RDATA,
    input wire [1:0] m_RRESP,
    input wire m_RLAST,
    
    // AXI Master - Write Address Channel
    output wire m_AWVALID,
    input wire m_AWREADY,
    output wire [WIDTH_ADDR-1:0] m_AWADDR,
    output wire [7:0] m_AWLEN,
    output wire [2:0] m_AWSIZE,
    output wire [1:0] m_AWBURST,
    
    // AXI Master - Write Data Channel
    output wire m_WVALID,
    input wire m_WREADY,
    output wire [WIDTH_DATA-1:0] m_WDATA,
    output wire [3:0] m_WSTRB,
    output wire m_WLAST,
    
    // AXI Master - Write Response Channel
    input wire m_BVALID,
    output wire m_BREADY,
    input wire [1:0] m_BRESP,

    // ===== AXI ACE Extensions =====
    output wire [3:0] m_ARSNOOP,
    output wire [1:0] m_ARDOMAIN,
    output wire [1:0] m_ARBAR,
    output wire [2:0] m_AWSNOOP,
    output wire [1:0] m_AWDOMAIN,
    output wire [1:0] m_AWBAR
);

    // Internal signals
    wire ready;
    wire valid_output;
    
    assign E_atomic_done = valid_output;
    assign atomic_stall = ~ready;
    
    // Snoop processing
    wire snoop_invalidate;
    reg snoop_invalidate_reg;
    reg [WIDTH_ADDR-1:0] snoop_addr_reg;
    reg [3:0] snoop_core_id_reg;
    
    // Fix: Register the invalidate signal to align with the address register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snoop_invalidate_reg <= 1'b0;
            snoop_addr_reg <= {WIDTH_ADDR{1'b0}};
            snoop_core_id_reg <= 4'b0;
        end else begin
            // Capture inputs
            snoop_invalidate_reg <= snoop_valid && (snoop_type == 4'h0 || snoop_type == 4'h1);
            
            if (snoop_valid) begin
                snoop_addr_reg <= snoop_addr;
                snoop_core_id_reg <= snoop_core_id;
            end
        end
    end
    
    assign snoop_invalidate = snoop_invalidate_reg;
    
    // Instantiate atomic unit
    atomic_unit_ace #(
        .WIDTH_DATA(WIDTH_DATA),
        .WIDTH_ADDR(WIDTH_ADDR),
        .CORE_ID(CORE_ID)
    ) atomic_core (
        // Clock and reset
        .clk(clk),
        .rst_n(rst_n),

        // Control
        .valid_input(E_AtomicOp),
        .ready(ready),
        .valid_output(valid_output),

        // Data
        .funct5(E_atomic_funct5),
        .aq(E_atomic_aq),
        .rl(E_atomic_rl),
        .addr(E_addr),
        .rs1_data(E_RD1),
        .rs2_data(E_RD2),
        .rd_value(E_atomic_rd),

        // Snoop
        .snoop_invalidate(snoop_invalidate),
        .snoop_addr(snoop_addr_reg),
        .snoop_core_id(snoop_core_id_reg),

        // Debug
        .debug_state(debug_state),
        .debug_reservation_valid(debug_reservation_valid),
        
        // AXI Read Address
        .m_ARVALID(m_ARVALID),
        .m_ARREADY(m_ARREADY),
        .m_ARADDR(m_ARADDR),
        .m_ARLEN(m_ARLEN),
        .m_ARSIZE(m_ARSIZE),
        .m_ARBURST(m_ARBURST),
        
        // AXI Read Data
        .m_RVALID(m_RVALID),
        .m_RREADY(m_RREADY),
        .m_RDATA(m_RDATA),
        .m_RRESP(m_RRESP),
        .m_RLAST(m_RLAST),
        
        // AXI Write Address
        .m_AWVALID(m_AWVALID),
        .m_AWREADY(m_AWREADY),
        .m_AWADDR(m_AWADDR),
        .m_AWLEN(m_AWLEN),
        .m_AWSIZE(m_AWSIZE),
        .m_AWBURST(m_AWBURST),
        
        // AXI Write Data
        .m_WVALID(m_WVALID),
        .m_WREADY(m_WREADY),
        .m_WDATA(m_WDATA),
        .m_WSTRB(m_WSTRB),
        .m_WLAST(m_WLAST),
        
        // AXI Write Response
        .m_BVALID(m_BVALID),
        .m_BREADY(m_BREADY),
        .m_BRESP(m_BRESP),

        // AXI ACE Extensions
        .m_ARSNOOP(m_ARSNOOP),
        .m_ARDOMAIN(m_ARDOMAIN),
        .m_ARBAR(m_ARBAR),
        .m_AWSNOOP(m_AWSNOOP),
        .m_AWDOMAIN(m_AWDOMAIN),
        .m_AWBAR(m_AWBAR)
    );

endmodule