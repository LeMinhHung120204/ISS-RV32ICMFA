module atomic_ex_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        i_atomic_valid,
    input  wire [4:0]  i_atomic_funct5,
    input  wire        i_atomic_aq,
    input  wire        i_atomic_rl,
    input  wire [2:0]  i_atomic_funct3,
    input  wire [31:0] i_rs1_data,
    input  wire [31:0] i_rs2_data,
    input  wire [31:0] i_offset,
    input  wire [4:0]  i_rd_addr,
    
    output reg         o_atomic_req,
    output reg  [3:0]  o_atomic_type,
    output reg         o_atomic_aq,
    output reg         o_atomic_rl,
    output reg  [31:0] o_atomic_addr,
    output reg  [31:0] o_atomic_wdata,
    output reg  [4:0]  o_atomic_rd,
    
    input  wire        i_atomic_ready,
    input  wire        i_atomic_done,
    input  wire [31:0] i_atomic_rdata,
    input  wire        i_atomic_resp
);

localparam [3:0] ATOMIC_LR   = 4'b0001;
localparam [3:0] ATOMIC_SC   = 4'b0010;
localparam [3:0] ATOMIC_SWAP = 4'b0011;
localparam [3:0] ATOMIC_ADD  = 4'b0100;
localparam [3:0] ATOMIC_AND  = 4'b0101;
localparam [3:0] ATOMIC_OR   = 4'b0110;
localparam [3:0] ATOMIC_XOR  = 4'b0111;
localparam [3:0] ATOMIC_MAX  = 4'b1000;
localparam [3:0] ATOMIC_MIN  = 4'b1001;
localparam [3:0] ATOMIC_MAXU = 4'b1010;
localparam [3:0] ATOMIC_MINU = 4'b1011;

reg req_pending;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_atomic_req   <= 1'b0;
        o_atomic_type  <= 4'b0;
        o_atomic_aq    <= 1'b0;
        o_atomic_rl    <= 1'b0;
        o_atomic_addr  <= 32'b0;
        o_atomic_wdata <= 32'b0;
        o_atomic_rd    <= 5'b0;
        req_pending    <= 1'b0;
    end else begin
        if (i_atomic_valid && !req_pending) begin
            o_atomic_addr  <= i_rs1_data + i_offset;
            o_atomic_wdata <= i_rs2_data;
            o_atomic_rd    <= i_rd_addr;
            o_atomic_aq    <= i_atomic_aq;
            o_atomic_rl    <= i_atomic_rl;
            
            case (i_atomic_funct5)
                5'b00010: o_atomic_type <= ATOMIC_LR;
                5'b00011: o_atomic_type <= ATOMIC_SC;
                5'b00001: o_atomic_type <= ATOMIC_SWAP;
                5'b00000: o_atomic_type <= ATOMIC_ADD;
                5'b01100: o_atomic_type <= ATOMIC_AND;
                5'b01000: o_atomic_type <= ATOMIC_OR;
                5'b00100: o_atomic_type <= ATOMIC_XOR;
                5'b10100: o_atomic_type <= ATOMIC_MAX;
                5'b10000: o_atomic_type <= ATOMIC_MIN;
                5'b11100: o_atomic_type <= ATOMIC_MAXU;
                5'b11000: o_atomic_type <= ATOMIC_MINU;
                default:  o_atomic_type <= 4'b0000;
            endcase
            
            o_atomic_req <= 1'b1;
            req_pending  <= 1'b1;
        end else if (i_atomic_done && req_pending) begin
            o_atomic_req <= 1'b0;
            req_pending  <= 1'b0;
        end
    end
end

endmodule
