`timescale 1ns/1ps
module non_restore_v2 #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_unsigned,
    input   [DATA_WIDTH - 1:0] dividend, divisor,
    output  [DATA_WIDTH - 1:0] quotient, remainder
);
    localparam num_reg = 8;
    localparam num_tmp = 8;

    reg [DATA_WIDTH:0]      M [0:num_reg - 1];
    reg [DATA_WIDTH:0]      A [0:num_reg - 1];
    reg [DATA_WIDTH-1:0]    Q [0:num_reg - 1];
    reg [num_reg-1:0]       sign;

    wire [DATA_WIDTH:0]     A_new[0:num_tmp-1];
    wire [DATA_WIDTH-1:0]   Q_new[0:num_tmp-1];
    wire [DATA_WIDTH:0]     divisor_ex;

    wire sign_a;
    wire sign_b;
    wire [DATA_WIDTH-1:0] abs_a, abs_b;
    wire [DATA_WIDTH:0] M0;

    assign divisor_ex   = (is_unsigned) ? {1'b0, divisor} : {divisor[DATA_WIDTH-1], divisor};
    assign sign_a       = ~is_unsigned & dividend[DATA_WIDTH-1];
    assign sign_b       = ~is_unsigned & divisor [DATA_WIDTH-1];
    assign abs_a        = sign_a ? (~dividend + 1'b1) : dividend;
    assign abs_b        = sign_b ? (~divisor  + 1'b1) : divisor;
    assign M0           = {1'b0, abs_b};

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1) begin
                Q[i] <= {DATA_WIDTH{1'b0}};
                M[i] <= {(DATA_WIDTH + 1){1'b0}};
                A[i] <= {(DATA_WIDTH + 1){1'b0}};
            end 
            sign    <= {(num_reg){1'b0}};
        end 
        else begin
            sign    <= {sign[num_reg-2:0], sign_a ^ sign_b};

            Q[0]    <= Q_new[0];
            A[0]    <= A_new[0];
            M[0]    <= M0;

            Q[1]    <= Q_new[1];
            A[1]    <= A_new[1];
            M[1]    <= M[0];

            Q[2]    <= Q_new[2];
            A[2]    <= A_new[2];
            M[2]    <= M[1];

            Q[3]    <= Q_new[3];
            A[3]    <= A_new[3];
            M[3]    <= M[2];

            Q[4]    <= Q_new[4];
            A[4]    <= A_new[4];
            M[4]    <= M[3];

            Q[5]    <= Q_new[5];
            A[5]    <= A_new[5];
            M[5]    <= M[4];

            Q[6]    <= Q_new[6];
            A[6]    <= A_new[6];
            M[6]    <= M[5];

            Q[7]    <= Q_new[7];
            A[7]    <= A_new[7];
            M[7]    <= M[6];
        end 
    end 

    wire [DATA_WIDTH-1:0] rem_abs;

    assign rem_abs      = (A[num_reg-1][DATA_WIDTH])    ? A[num_reg-1] + M[num_reg-1]   : A[num_reg-1];
    assign quotient     = (sign[num_reg - 1])           ? ~Q[num_reg - 1] + 1'b1        : Q[num_reg - 1];
    assign remainder    = (sign[num_reg - 1])           ? ~rem_abs + 1'b1               : rem_abs;

    DivStageK #(.W(DATA_WIDTH), .K(4)) u_stage_first (
        .A_in({(DATA_WIDTH + 1){1'b0}}),
        .M_in(M0),
        .Q_in(abs_a),
        .A_out(A_new[0]),
        .Q_out(Q_new[0])
    );

    genvar gi;
    generate
        for (gi = 1 ; gi < 8; gi = gi + 1) begin : GEN_STAGES
            DivStageK #(.W(DATA_WIDTH), .K(4)) stg(
                .A_in(A[gi - 1]),
                .M_in(M[gi - 1]),
                .Q_in(Q[gi - 1]),
                .A_out(A_new[gi]),
                .Q_out(Q_new[gi]) 
            );
        end
    endgenerate

endmodule