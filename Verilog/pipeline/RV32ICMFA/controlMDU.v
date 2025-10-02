`timescale 1ns/1ps
module controlMDU #(
    parameter DATA_WIDTH = 32
)(
    input           clk, rst_n,
    input           MDU_valid,      // = 1 Khi co lenh MUL/DIV/REM*
    input           is_mul_issue,   // 1: MUL*, 0: DIV/REM*
    input   [2:0]   funct3,
    input   [4:0]   inRD,

    output          mul_done_valid,
    output  [2:0]   mul_done_funct3,
    output  [4:0]   mul_done_rd,

    output          div_done_valid,
    output  [2:0]   div_done_funct3,
    output  [4:0]   div_done_rd,

    output  MDU_is_busy
);

    // MUL meta pipe (4 stage)    
    reg [3:0]  mul_v;
    reg [2:0]  mul_f3 [0:3];
    reg [4:0]  mul_rd [0:3];

    
    // DIV meta pipe (8 stage)
    reg [7:0]  div_v;
    reg [2:0]  div_f3 [0:7];
    reg [4:0]  div_rd [0:7];
    reg [31:0] reg_busy;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_v       <= 4'b0;
            div_v       <= 8'b0;
            reg_busy    <= 32'b0;
            for (i = 0; i < 4; i = i + 1) begin
                mul_f3[i] <= 3'd0;
                mul_rd[i] <= 5'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                div_f3[i] <= 3'd0;
                div_rd[i] <= 5'd0;
            end
        end 
        else begin
            if (~reg_busy[inRD]) begin
                reg_busy[inRD]  <= MDU_valid;
                mul_v[0]        <= MDU_valid &  is_mul_issue;
                mul_f3[0]       <= funct3;
                mul_rd[0]       <= inRD;

                div_v[0]        <= MDU_valid & ~is_mul_issue;
                div_f3[0]       <= funct3;
                div_rd[0]       <= inRD;

            end
            // --- MUL shift ---
            reg_busy[inRD]  <= MDU_valid;
            mul_v[3]   <= mul_v[2];
            mul_v[2]   <= mul_v[1];
            mul_v[1]   <= mul_v[0];            

            mul_f3[3]  <= mul_f3[2];
            mul_f3[2]  <= mul_f3[1];
            mul_f3[1]  <= mul_f3[0];            

            mul_rd[3]  <= mul_rd[2];
            mul_rd[2]  <= mul_rd[1];
            mul_rd[1]  <= mul_rd[0];
            
            // --- DIV shift ---
            div_v[7]   <= div_v[6];
            div_v[6]   <= div_v[5];
            div_v[5]   <= div_v[4];
            div_v[4]   <= div_v[3];
            div_v[3]   <= div_v[2];
            div_v[2]   <= div_v[1];
            div_v[1]   <= div_v[0];
            
            div_f3[7]  <= div_f3[6];
            div_f3[6]  <= div_f3[5];
            div_f3[5]  <= div_f3[4];
            div_f3[4]  <= div_f3[3];
            div_f3[3]  <= div_f3[2];
            div_f3[2]  <= div_f3[1];
            div_f3[1]  <= div_f3[0];
            
            div_rd[7]  <= div_rd[6];
            div_rd[6]  <= div_rd[5];
            div_rd[5]  <= div_rd[4];
            div_rd[4]  <= div_rd[3];
            div_rd[3]  <= div_rd[2];
            div_rd[2]  <= div_rd[1];
            div_rd[1]  <= div_rd[0];
        end
    end

    assign mul_done_valid   = mul_v[3];
    assign mul_done_funct3  = mul_f3[3];
    assign mul_done_rd      = mul_rd[3];

    assign div_done_valid   = div_v[7];
    assign div_done_funct3  = div_f3[7];
    assign div_done_rd      = div_rd[7];

    assign MDU_is_busy      = mul_v[3] & div_v[7];

endmodule
