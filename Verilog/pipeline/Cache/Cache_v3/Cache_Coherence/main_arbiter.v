`timescale 1ns/1ps

module main_l2_arbiter #(
    parameter ADDR_W = 32,
    parameter LINE_W = 128
)(
    input clk   
,   input rst_n

    // ==========================================
    // INPUT TỪ I_ARBITER (Luồng Instruction)
    // ==========================================
,   output                  o_l2_i_req_ready
,   input                   i_l2_i_req_valid
,   input   [ADDR_W-1:0]    i_l2_i_req_addr
    
,   input                   i_l2_i_rdata_ready
,   output                  o_l2_i_rdata_valid
,   output  [LINE_W-1:0]    o_l2_i_rdata

    // ==========================================
    // INPUT TỪ D_COHERENCE (Luồng Data)
    // ==========================================
,   output                  o_l2_d_req_ready
,   input                   i_l2_d_req_valid
,   input   [ADDR_W-1:0]    i_l2_d_req_addr
,   input                   i_l2_d_req_rw
,   input   [LINE_W-1:0]    i_l2_d_req_wdata

,   input                   i_l2_d_resp_ready
,   output                  o_l2_d_resp_valid
,   output  [LINE_W-1:0]    o_l2_d_resp_rdata

    // ==========================================
    // OUTPUT XUỐNG SHARED L2 CACHE
    // ==========================================
,   input                   i_l2_req_ready
,   output                  o_l2_req_valid
,   output  [ADDR_W-1:0]    o_l2_req_addr
,   output                  o_l2_req_rw     // 0: Read, 1: Write
,   output  [LINE_W-1:0]    o_l2_req_wdata

,   input                   i_l2_resp_valid
,   input   [LINE_W-1:0]    i_l2_resp_rdata
,   output                  o_l2_resp_ready
);

    // ================================================================
    // FSM STATES
    // ================================================================
    localparam IDLE     = 2'd0;
    localparam SERVE_D  = 2'd1;
    localparam SERVE_I  = 2'd2;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) 
            state <= IDLE;
        else        
            state <= next_state;
    end

    // ================================================================
    // DATAPATH: Gán trực tiếp dữ liệu đọc từ L2 lên
    // ================================================================
    assign o_l2_d_resp_rdata    = i_l2_resp_rdata;
    assign o_l2_i_rdata         = i_l2_resp_rdata;

    // ================================================================
    // FSM NEXT STATE & CONTROL LOGIC
    // ================================================================
    reg mux_d_sel; // 1 = Chọn Data, 0 = Chọn Instruction

    always @(*) begin
        next_state          = state;
        
        // Default Outputs
        o_l2_d_req_ready    = 1'b0;
        o_l2_i_req_ready    = 1'b0;
        o_l2_d_resp_valid   = 1'b0;
        o_l2_i_rdata_valid  = 1'b0;
        
        o_l2_req_valid      = 1'b0;
        o_l2_resp_ready     = 1'b0;
        mux_d_sel           = 1'b0;

        case (state)
            IDLE: begin
                // Fixed Priority: Luôn check Data trước
                if (i_l2_d_req_valid) begin
                    o_l2_req_valid          = 1'b1;
                    mux_d_sel               = 1'b1;
                    
                    if (i_l2_req_ready) begin
                        o_l2_d_req_ready    = 1'b1;
                        next_state          = SERVE_D;
                    end
                end 
                else if (i_l2_i_req_valid) begin
                    o_l2_req_valid          = 1'b1;
                    mux_d_sel               = 1'b0;
                    
                    if (i_l2_req_ready) begin
                        o_l2_i_req_ready    = 1'b1;
                        next_state          = SERVE_I;
                    end
                end
            end

            SERVE_D: begin
                mux_d_sel       = 1'b1;
                o_l2_resp_ready = i_l2_d_resp_ready;
                
                // Trả cờ valid về cho D-Coherence
                if (i_l2_resp_valid) begin
                    o_l2_d_resp_valid   = 1'b1;
                    if (i_l2_d_resp_ready) 
                        next_state      = IDLE;
                end
            end

            SERVE_I: begin
                mux_d_sel               = 1'b0;
                o_l2_resp_ready         = i_l2_i_rdata_ready;
                
                // Trả cờ valid về cho I-Arbiter
                if (i_l2_resp_valid) begin
                    o_l2_i_rdata_valid  = 1'b1;
                    if (i_l2_i_rdata_ready) 
                        next_state      = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // ================================================================
    // MULTIPLEXER (Định tuyến Address và Data xuống L2)
    // ================================================================
    assign o_l2_req_addr     = (mux_d_sel) ? i_l2_d_req_addr  : i_l2_i_req_addr;
    assign o_l2_req_rw      = (mux_d_sel) ? i_l2_d_req_rw    : 1'b0; // I-Cache luôn là Read (0)
    assign o_l2_req_wdata   = (mux_d_sel) ? i_l2_d_req_wdata : {LINE_W{1'b0}};

endmodule