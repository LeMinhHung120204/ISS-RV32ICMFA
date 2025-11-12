`timescale 1ns / 1ps

module atomic_unit_ace(
    ACLK,
    ARESETn,
    valid_input,
    ready,
    valid_output,
    atomic_op,
    rs1_value,
    rs2_value,
    rd_value,
    aq,
    rl,
    m_ARID,
    m_ARADDR,
    m_ARLEN,
    m_ARSIZE,
    m_ARBURST,
    m_ARLOCK,
    m_ARCACHE,
    m_ARPROT,
    m_ARQOS,
    m_ARREGION,
    m_ARDOMAIN,
    m_ARSNOOP,
    m_ARBAR,
    m_ARVALID,
    m_ARREADY,
    m_RID,
    m_RDATA,
    m_RRESP,
    m_RLAST,
    m_RVALID,
    m_RREADY,
    m_AWID,
    m_AWADDR,
    m_AWLEN,
    m_AWSIZE,
    m_AWBURST,
    m_AWLOCK,
    m_AWCACHE,
    m_AWPROT,
    m_AWQOS,
    m_AWREGION,
    m_AWDOMAIN,
    m_AWSNOOP,
    m_AWBAR,
    m_AWVALID,
    m_AWREADY,
    m_WDATA,
    m_WSTRB,
    m_WLAST,
    m_WVALID,
    m_WREADY,
    m_BID,
    m_BRESP,
    m_BVALID,
    m_BREADY
);

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;
parameter ID_WIDTH = 2;

// System
input            ACLK;
input            ARESETn;

// Control
input            valid_input;
output reg       ready;
output reg       valid_output;

// Operation
input  [3:0]              atomic_op;
input  [ADDR_WIDTH-1:0]   rs1_value;
input  [DATA_WIDTH-1:0]   rs2_value;
output reg [DATA_WIDTH-1:0] rd_value;
input            aq;
input            rl;

// ACE Read Address Channel
output reg [ID_WIDTH-1:0]     m_ARID;
output reg [ADDR_WIDTH-1:0]   m_ARADDR;
output reg [7:0]              m_ARLEN;
output reg [2:0]              m_ARSIZE;
output reg [1:0]              m_ARBURST;
output reg                    m_ARLOCK;
output reg [3:0]              m_ARCACHE;
output reg [2:0]              m_ARPROT;
output reg [3:0]              m_ARQOS;
output reg [3:0]              m_ARREGION;
output reg [1:0]              m_ARDOMAIN;
output reg [3:0]              m_ARSNOOP;
output reg [1:0]              m_ARBAR;
output reg                    m_ARVALID;
input                         m_ARREADY;

// ACE Read Data Channel
input [ID_WIDTH-1:0]     m_RID;
input [DATA_WIDTH-1:0]   m_RDATA;
input [1:0]              m_RRESP;
input                    m_RLAST;
input                    m_RVALID;
output reg               m_RREADY;

// ACE Write Address Channel
output reg [ID_WIDTH-1:0]     m_AWID;
output reg [ADDR_WIDTH-1:0]   m_AWADDR;
output reg [7:0]              m_AWLEN;
output reg [2:0]              m_AWSIZE;
output reg [1:0]              m_AWBURST;
output reg                    m_AWLOCK;
output reg [3:0]              m_AWCACHE;
output reg [2:0]              m_AWPROT;
output reg [3:0]              m_AWQOS;
output reg [3:0]              m_AWREGION;
output reg [1:0]              m_AWDOMAIN;
output reg [2:0]              m_AWSNOOP;
output reg [1:0]              m_AWBAR;
output reg                    m_AWVALID;
input                         m_AWREADY;

// ACE Write Data Channel
output reg [DATA_WIDTH-1:0]   m_WDATA;
output reg [3:0]              m_WSTRB;
output reg                    m_WLAST;
output reg                    m_WVALID;
input                         m_WREADY;

// ACE Write Response Channel
input [ID_WIDTH-1:0]     m_BID;
input [1:0]              m_BRESP;
input                    m_BVALID;
output reg               m_BREADY;

// Operation codes
localparam OP_LR       = 4'b0000;
localparam OP_SC       = 4'b0001;
localparam OP_AMOSWAP  = 4'b0010;
localparam OP_AMOADD   = 4'b0011;
localparam OP_AMOXOR   = 4'b0100;
localparam OP_AMOAND   = 4'b0101;
localparam OP_AMOOR    = 4'b0110;
localparam OP_AMOMIN   = 4'b0111;
localparam OP_AMOMAX   = 4'b1000;
localparam OP_AMOMINU  = 4'b1001;
localparam OP_AMOMAXU  = 4'b1010;

// FSM states
localparam IDLE   = 3'b000;
localparam READ   = 3'b001;
localparam ALU    = 3'b010;
localparam WRITE  = 3'b011;
localparam CHECK  = 3'b100;
localparam DONE   = 3'b101;

// ACE snoop types
localparam ARSNOOP_READONCE   = 4'b0000;
localparam ARSNOOP_READUNIQUE = 4'b0111;
localparam AWSNOOP_WRITENSNOOP = 3'b000;
localparam AWSNOOP_WRITEUNIQUE = 3'b001;

// ACE domains
localparam DOMAIN_NONSHAREABLE = 2'b00;
localparam DOMAIN_INNER        = 2'b01;

// Internal registers
reg [2:0]              state, next_state;
reg [3:0]              op_reg;
reg [ADDR_WIDTH-1:0]   addr_reg;
reg [DATA_WIDTH-1:0]   data_reg;
reg [DATA_WIDTH-1:0]   rdata_reg;
reg [DATA_WIDTH-1:0]   result_reg;
reg                    aq_reg, rl_reg;
reg                    reservation_valid;
reg [ADDR_WIDTH-1:0]   reservation_addr;

// FSM sequential
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn)
        state <= IDLE;
    else
        state <= next_state;
end

// FSM combinational
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (valid_input) begin
                if (atomic_op == OP_SC)
                    next_state = CHECK;
                else
                    next_state = READ;
            end
        end
        READ: begin
            if (m_RVALID && m_RREADY)
                next_state = (op_reg == OP_LR) ? DONE : ALU;
        end
        ALU:
            next_state = WRITE;
        WRITE: begin
            if (m_BVALID && m_BREADY)
                next_state = DONE;
        end
        CHECK:
            next_state = (reservation_valid && (reservation_addr == addr_reg)) ? WRITE : DONE;
        DONE:
            next_state = IDLE;
        default:
            next_state = IDLE;
    endcase
end

// Capture inputs
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        op_reg   <= 4'b0;
        addr_reg <= {ADDR_WIDTH{1'b0}};
        data_reg <= {DATA_WIDTH{1'b0}};
        aq_reg   <= 1'b0;
        rl_reg   <= 1'b0;
    end else if (state == IDLE && valid_input) begin
        op_reg   <= atomic_op;
        addr_reg <= rs1_value;
        data_reg <= rs2_value;
        aq_reg   <= aq;
        rl_reg   <= rl;
    end
end

// Capture read data
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn)
        rdata_reg <= {DATA_WIDTH{1'b0}};
    else if (state == READ && m_RVALID)
        rdata_reg <= m_RDATA;
end

// ALU computation
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn)
        result_reg <= {DATA_WIDTH{1'b0}};
    else if (state == ALU) begin
        case (op_reg)
            OP_AMOSWAP:  result_reg <= data_reg;
            OP_AMOADD:   result_reg <= rdata_reg + data_reg;
            OP_AMOXOR:   result_reg <= rdata_reg ^ data_reg;
            OP_AMOOR:    result_reg <= rdata_reg | data_reg;
            OP_AMOAND:   result_reg <= rdata_reg & data_reg;
            OP_AMOMIN:   result_reg <= ($signed(rdata_reg) < $signed(data_reg)) ? rdata_reg : data_reg;
            OP_AMOMAX:   result_reg <= ($signed(rdata_reg) > $signed(data_reg)) ? rdata_reg : data_reg;
            OP_AMOMINU:  result_reg <= (rdata_reg < data_reg) ? rdata_reg : data_reg;
            OP_AMOMAXU:  result_reg <= (rdata_reg > data_reg) ? rdata_reg : data_reg;
            default:     result_reg <= {DATA_WIDTH{1'b0}};
        endcase
    end
end

// Reservation set for LR/SC
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        reservation_valid <= 1'b0;
        reservation_addr  <= {ADDR_WIDTH{1'b0}};
    end else begin
        if (state == READ && op_reg == OP_LR && m_RVALID) begin
            reservation_valid <= 1'b1;
            reservation_addr  <= addr_reg;
        end
        else if (state == DONE && op_reg == OP_SC)
            reservation_valid <= 1'b0;
    end
end

// Output generation
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        valid_output <= 1'b0;
        rd_value     <= {DATA_WIDTH{1'b0}};
    end else if (state == DONE) begin
        valid_output <= 1'b1;
        case (op_reg)
            OP_LR:
                rd_value <= rdata_reg;
            OP_SC:
                rd_value <= (reservation_valid && (reservation_addr == addr_reg)) ? 
                      {DATA_WIDTH{1'b0}} : {{(DATA_WIDTH-1){1'b0}}, 1'b1};
            default:
                rd_value <= rdata_reg;
        endcase
    end else
        valid_output <= 1'b0;
end

always @(*) begin
    ready = (state == IDLE);
end

// ACE Read Address
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        m_ARVALID   <= 1'b0;
        m_ARADDR    <= {ADDR_WIDTH{1'b0}};
        m_ARLEN     <= 8'h0;
        m_ARSIZE    <= 3'b010;
        m_ARBURST   <= 2'b01;
        m_ARLOCK    <= 1'b0;
        m_ARCACHE   <= 4'b0000;
        m_ARPROT    <= 3'b000;
        m_ARQOS     <= 4'b0000;
        m_ARREGION  <= 4'b0000;
        m_ARDOMAIN  <= DOMAIN_NONSHAREABLE;
        m_ARSNOOP   <= ARSNOOP_READONCE;
        m_ARBAR     <= 2'b00;
        m_ARID      <= {ID_WIDTH{1'b0}};
    end else begin
        if (state == READ && !m_ARVALID) begin
            m_ARADDR   <= addr_reg;
            m_ARLEN    <= 8'h0;
            m_ARSIZE   <= 3'b010;
            m_ARBURST  <= 2'b01;
            m_ARLOCK   <= 1'b0;
            m_ARCACHE  <= 4'b0000;
            m_ARPROT   <= 3'b000;
            m_ARQOS    <= 4'b0000;
            m_ARREGION <= 4'b0000;
            m_ARID     <= {ID_WIDTH{1'b0}};
            
            if (op_reg == OP_LR || (op_reg >= OP_AMOSWAP && op_reg <= OP_AMOMAXU)) begin
                m_ARDOMAIN <= DOMAIN_INNER;
                m_ARSNOOP  <= ARSNOOP_READUNIQUE;
            end else begin
                m_ARDOMAIN <= DOMAIN_NONSHAREABLE;
                m_ARSNOOP  <= ARSNOOP_READONCE;
            end
            
            m_ARBAR   <= {rl_reg, aq_reg};
            m_ARVALID <= 1'b1;
        end
        else if (m_ARREADY)
            m_ARVALID <= 1'b0;
    end
end

always @(*) begin
    m_RREADY = (state == READ);
end

// ACE Write Address
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        m_AWVALID   <= 1'b0;
        m_AWADDR    <= {ADDR_WIDTH{1'b0}};
        m_AWLEN     <= 8'h0;
        m_AWSIZE    <= 3'b010;
        m_AWBURST   <= 2'b01;
        m_AWLOCK    <= 1'b0;
        m_AWCACHE   <= 4'b0000;
        m_AWPROT    <= 3'b000;
        m_AWQOS     <= 4'b0000;
        m_AWREGION  <= 4'b0000;
        m_AWDOMAIN  <= DOMAIN_NONSHAREABLE;
        m_AWSNOOP   <= AWSNOOP_WRITENSNOOP;
        m_AWBAR     <= 2'b00;
        m_AWID      <= {ID_WIDTH{1'b0}};
    end else begin
        if (state == WRITE && !m_AWVALID) begin
            m_AWADDR   <= addr_reg;
            m_AWLEN    <= 8'h0;
            m_AWSIZE   <= 3'b010;
            m_AWBURST  <= 2'b01;
            m_AWLOCK   <= 1'b0;
            m_AWCACHE  <= 4'b0000;
            m_AWPROT   <= 3'b000;
            m_AWQOS    <= 4'b0000;
            m_AWREGION <= 4'b0000;
            m_AWID     <= {ID_WIDTH{1'b0}};
            
            if (op_reg == OP_SC || (op_reg >= OP_AMOSWAP && op_reg <= OP_AMOMAXU)) begin
                m_AWDOMAIN <= DOMAIN_INNER;
                m_AWSNOOP  <= AWSNOOP_WRITEUNIQUE;
            end else begin
                m_AWDOMAIN <= DOMAIN_NONSHAREABLE;
                m_AWSNOOP  <= AWSNOOP_WRITENSNOOP;
            end
            
            m_AWBAR   <= {rl_reg, aq_reg};
            m_AWVALID <= 1'b1;
        end
        else if (m_AWREADY)
            m_AWVALID <= 1'b0;
    end
end

// ACE Write Data
always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) begin
        m_WVALID <= 1'b0;
        m_WDATA  <= {DATA_WIDTH{1'b0}};
        m_WSTRB  <= 4'b0000;
        m_WLAST  <= 1'b0;
    end else begin
        if (state == WRITE && !m_WVALID) begin
            m_WDATA  <= (op_reg == OP_SC) ? data_reg : result_reg;
            m_WSTRB  <= 4'b1111;
            m_WLAST  <= 1'b1;
            m_WVALID <= 1'b1;
        end
        else if (m_WREADY)
            m_WVALID <= 1'b0;
    end
end

always @(*) begin
    m_BREADY = (state == WRITE);
end

endmodule
