`timescale 1ns/1ps
module non_restore #(
    parameter DATA_WIDTH = 32
)(
    input clk, rst_n,
    input [DATA_WIDTH - 1:0] dividend, divisor,
    output [DATA_WIDTH - 1:0] quotient, remainder
);
    localparam num_reg = 33;

    reg [DATA_WIDTH:0]      M [0:num_reg - 1];
    reg [DATA_WIDTH:0]      A [0:num_reg - 1];
    reg [DATA_WIDTH-1:0]    Q [0:num_reg - 1];

    // wire [DATA_WIDTH:0]     M_tmp [0:num_reg - 1];
    wire [DATA_WIDTH:0]     A_tmp [0:num_reg - 1];
    wire [DATA_WIDTH:0]     A_new [0:num_reg - 1];
    wire [DATA_WIDTH-1:0]   Q_tmp [0:num_reg - 1];
    wire [DATA_WIDTH-1:0]   Q_new [0:num_reg - 1];

    assign {A_tmp[0], Q_tmp[0]} = {A[0][DATA_WIDTH-1:0], Q[0], 1'b0};
    assign A_new[0]             = (A[0][DATA_WIDTH]) ? A_tmp[0] + M[0] : A_tmp[0] - M[0];
    assign Q_new[0]             = {Q_tmp[0][DATA_WIDTH-1:1], (~A_new[0][DATA_WIDTH])};

    genvar gi;
    generate
        for (gi = 1; gi < num_reg; gi = gi + 1) begin
            assign {A_tmp[gi], Q_tmp[gi]}   = {A[gi][DATA_WIDTH - 1:0], Q[gi], 1'b0};
            assign A_new[gi]                = (A_tmp[gi][DATA_WIDTH]) ? A_tmp[gi] + M[gi] : A_tmp[gi] - M[gi];
            assign Q_new[gi]                = {Q_tmp[gi][DATA_WIDTH-1:1], (~A_new[gi][DATA_WIDTH])};
        end 
    endgenerate
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1) begin
                Q[i] <= {DATA_WIDTH{1'b0}};
                M[i] <= {(DATA_WIDTH + 1){1'b0}};
                A[i] <= {(DATA_WIDTH + 1){1'b0}};
            end 
            
        end 
        else begin
            Q[0] <= dividend;
            M[0] <= {1'b0, divisor};
            A[0] <= {(DATA_WIDTH + 1){1'b0}};

            for (i = 1; i < num_reg; i = i + 1) begin
                Q[i] <= Q_new[i - 1];
                M[i] <= M[i - 1];
                A[i] <= A_new[i - 1];
            end 
        end 
    end
    assign quotient     = Q[num_reg - 1];
    assign remainder    = (A[num_reg-1][DATA_WIDTH]) ? A[num_reg-1] + M[num_reg-1] : A[num_reg-1];

endmodule