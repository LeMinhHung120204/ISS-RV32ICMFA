`timescale 1ns/1ps
// Round-Robin Arbiter
module arbiter #(
    parameter ADDR_W = 32
)(
    input   clk, rst_n,

    // --- Client 0: I-Cache (Read Only) ---
    input                       i_c0_req_valid,
    input   [ADDR_W-1:0]        i_c0_req_addr,
    output  reg                 o_c0_req_ready,

    // --- Client 1: D-Cache (Read/Write) ---
    input                       i_c1_req_valid,
    input   [1:0]               i_c1_req_cmd,
    input   [ADDR_W-1:0]        i_c1_req_addr,
    output  reg                 o_c1_req_ready,

    // --- Output to L2 Cache ---
    input                       i_l2_ready,     // L2 san sang nhan lenh
    output  reg                 o_l2_valid,     // Co lenh gui xuong L2
    output  reg [1:0]           o_l2_cmd,       // Lenh gi
    output  reg [ADDR_W-1:0]    o_l2_addr       // Dia chi nao
);
    reg priority_ptr;
    reg grant_c0;
    reg grant_c1;

    reg state;        // 0 = IDLE, 1 = BUSY
    reg cur_grant;    // 0 = C0, 1 = C1

    // always @(*) begin
    //     grant_c0 = 1'b0;
    //     grant_c1 = 1'b0;

    //     if (priority_ptr == 1'b0) begin 
    //         // uu tien Client 0
    //         if (i_c0_req_valid) begin
    //             grant_c0 = 1'b1;
    //         end 
    //         else if (i_c1_req_valid) begin
    //             grant_c1 = 1'b1;
    //         end
    //     end 
    //     else begin 
    //         // uu tien Client 1
    //         if (i_c1_req_valid) begin
    //             grant_c1 = 1'b1;
    //         end 
    //         else if (i_c0_req_valid) begin
    //             grant_c0 = 1'b1;
    //         end
    //     end
    // end
    always @(*) begin
        grant_c0 = 1'b0;
        grant_c1 = 1'b0;

        if (state == 1'b0) begin
            if (priority_ptr == 1'b0) begin
                if (i_c0_req_valid) begin      
                    grant_c0 = 1'b1;
                end 
                else if (i_c1_req_valid) begin 
                    grant_c1 = 1'b1;
                end 
            end 
            else begin
                if (i_c1_req_valid) begin      
                    grant_c1 = 1'b1;
                end 
                else if (i_c0_req_valid) begin 
                    grant_c0 = 1'b1;
                end
            end
        end
    end

    // always @(*) begin
    //     o_l2_valid      = 1'b0;
    //     o_l2_cmd        = 2'b00;
    //     o_l2_addr       = {ADDR_W{1'b0}};
    //     o_c0_req_ready  = 1'b0;
    //     o_c1_req_ready  = 1'b0;

    //     if (grant_c0) begin
    //         // I-Cache win
    //         o_l2_valid      = 1'b1;
    //         o_l2_cmd        = 2'b00;        // I-Cache luon la READ
    //         o_l2_addr       = i_c0_req_addr;

    //         // tra ready cho I-Cache khi L2 read
    //         o_c0_req_ready  = i_l2_ready; 
    //     end
    //     else if (grant_c1) begin
    //         // D-Cache win
    //         o_l2_valid      = 1'b1;
    //         o_l2_cmd        = i_c1_req_cmd;
    //         o_l2_addr       = i_c1_req_addr;
            
    //         // tra ready cho D-Cache khi L2 ready
    //         o_c1_req_ready  = i_l2_ready;
    //     end
    // end

    always @(*) begin
        o_l2_valid      = (state == 1'b1);
        o_l2_cmd        = 2'b00;
        o_l2_addr       = '0;
        o_c0_req_ready  = 1'b0;
        o_c1_req_ready  = 1'b0;

        if (state == 1'b1) begin
            if (cur_grant == 1'b0) begin
                o_l2_cmd        = 2'b00;
                o_l2_addr       = i_c0_req_addr;
                o_c0_req_ready  = i_l2_ready;
            end 
            else begin
                o_l2_cmd        = i_c1_req_cmd;
                o_l2_addr       = i_c1_req_addr;
                o_c1_req_ready  = i_l2_ready;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state           <= 1'b0;
            priority_ptr    <= 1'b0;
        end 
        else begin
            case (state)
                1'b0: begin // IDLE
                    if (grant_c0 | grant_c1) begin
                        state       <= 1'b1;
                        cur_grant   <= grant_c1; // 1 = C1
                    end
                end

                1'b1: begin // BUSY
                    if (i_l2_ready) begin
                        state           <= 1'b0;
                        priority_ptr    <= cur_grant; // swap priority
                    end
                end
            endcase
        end
    end

endmodule