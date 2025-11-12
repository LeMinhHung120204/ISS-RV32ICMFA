`timescale 1ns/1ps

module atomic_wrapper (
    input clk,
    input rst_n,
    
    // Pipeline interface
    input E_AtomicOp,  // ATOMIC: Atomic operation flag
    input [4:0] E_atomic_funct5,
    input E_atomic_aq,
    input E_atomic_rl,
    input [31:0] E_RD1,
    input [31:0] E_RD2,
    
    output E_atomic_done,
    output [31:0] E_atomic_rd,
    output atomic_stall,
    
    // ACE Master Interface - Read Address Channel
    output [1:0] m_ARID,
    output [31:0] m_ARADDR,
    output [7:0] m_ARLEN,
    output [2:0] m_ARSIZE,
    output [1:0] m_ARBURST,
    output m_ARLOCK,
    output [3:0] m_ARCACHE,
    output [2:0] m_ARPROT,
    output [3:0] m_ARQOS,
    output [3:0] m_ARREGION,
    output [1:0] m_ARDOMAIN,
    output [3:0] m_ARSNOOP,
    output [1:0] m_ARBAR,
    output m_ARVALID,
    input m_ARREADY,
    
    // Read Data Channel
    input [1:0] m_RID,
    input [31:0] m_RDATA,
    input [1:0] m_RRESP,
    input m_RLAST,
    input m_RVALID,
    output m_RREADY,
    
    // Write Address Channel
    output [1:0] m_AWID,
    output [31:0] m_AWADDR,
    output [7:0] m_AWLEN,
    output [2:0] m_AWSIZE,
    output [1:0] m_AWBURST,
    output m_AWLOCK,
    output [3:0] m_AWCACHE,
    output [2:0] m_AWPROT,
    output [3:0] m_AWQOS,
    output [3:0] m_AWREGION,
    output [1:0] m_AWDOMAIN,
    output [2:0] m_AWSNOOP,
    output [1:0] m_AWBAR,
    output m_AWVALID,
    input m_AWREADY,
    
    // Write Data Channel
    output [31:0] m_WDATA,
    output [3:0] m_WSTRB,
    output m_WLAST,
    output m_WVALID,
    input m_WREADY,
    
    // Write Response Channel
    input [1:0] m_BID,
    input [1:0] m_BRESP,
    input m_BVALID,
    output m_BREADY
);

    wire [3:0] atomic_op;

    // ATOMIC: Instantiate decoder
    atomic_decoder decoder_inst (
        .atomic_funct5(E_atomic_funct5),
        .atomic_op(atomic_op)
    );

    // ATOMIC: Instantiate execution unit
    atomic_unit_ace unit_inst (
        .clk(clk),
        .rst_n(rst_n),
        .atomic_op(atomic_op),
        .rs1_value(E_RD1),
        .rs2_value(E_RD2),
        .aq(E_atomic_aq),
        .rl(E_atomic_rl),
        .rd_value(E_atomic_rd),
        .done(E_atomic_done),
        
        // ACE interface
        .m_ARID(m_ARID),
        .m_ARADDR(m_ARADDR),
        .m_ARLEN(m_ARLEN),
        .m_ARSIZE(m_ARSIZE),
        .m_ARBURST(m_ARBURST),
        .m_ARLOCK(m_ARLOCK),
        .m_ARCACHE(m_ARCACHE),
        .m_ARPROT(m_ARPROT),
        .m_ARQOS(m_ARQOS),
        .m_ARREGION(m_ARREGION),
        .m_ARDOMAIN(m_ARDOMAIN),
        .m_ARSNOOP(m_ARSNOOP),
        .m_ARBAR(m_ARBAR),
        .m_ARVALID(m_ARVALID),
        .m_ARREADY(m_ARREADY),
        
        .m_RID(m_RID),
        .m_RDATA(m_RDATA),
        .m_RRESP(m_RRESP),
        .m_RLAST(m_RLAST),
        .m_RVALID(m_RVALID),
        .m_RREADY(m_RREADY),
        
        .m_AWID(m_AWID),
        .m_AWADDR(m_AWADDR),
        .m_AWLEN(m_AWLEN),
        .m_AWSIZE(m_AWSIZE),
        .m_AWBURST(m_AWBURST),
        .m_AWLOCK(m_AWLOCK),
        .m_AWCACHE(m_AWCACHE),
        .m_AWPROT(m_AWPROT),
        .m_AWQOS(m_AWQOS),
        .m_AWREGION(m_AWREGION),
        .m_AWDOMAIN(m_AWDOMAIN),
        .m_AWSNOOP(m_AWSNOOP),
        .m_AWBAR(m_AWBAR),
        .m_AWVALID(m_AWVALID),
        .m_AWREADY(m_AWREADY),
        
        .m_WDATA(m_WDATA),
        .m_WSTRB(m_WSTRB),
        .m_WLAST(m_WLAST),
        .m_WVALID(m_WVALID),
        .m_WREADY(m_WREADY),
        
        .m_BID(m_BID),
        .m_BRESP(m_BRESP),
        .m_BVALID(m_BVALID),
        .m_BREADY(m_BREADY)
    );

    // ATOMIC: Signal stall to pipeline
    assign atomic_stall = E_AtomicOp & (~E_atomic_done);

endmodule
