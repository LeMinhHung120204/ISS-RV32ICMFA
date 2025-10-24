`timescale 1ns/1ps
module non_restore #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_unsigned,
    input   [DATA_WIDTH - 1:0] dividend, divisor,
    output  [DATA_WIDTH - 1:0] quotient, remainder
);
    localparam num_reg = 11;
    localparam num_tmp = 11;

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

            Q[8]    <= Q_new[8];
            A[8]    <= A_new[8];
            M[8]    <= M[7];

            Q[9]    <= Q_new[9];
            A[9]    <= A_new[9];
            M[9]    <= M[8];

            Q[10]   <= Q_new[10];
            A[10]   <= A_new[10];
            M[10]   <= M[9];

            // Q[11]   <= Q_new[11];
            // A[11]   <= A_new[11];
            // M[11]   <= M[10];

            // Q[12]   <= Q_new[12];
            // A[12]   <= A_new[12];
            // M[12]   <= M[11];

            // Q[13]   <= Q_new[13];
            // A[13]   <= A_new[13];
            // M[13]   <= M[12];

            // Q[14]   <= Q_new[14];
            // A[14]   <= A_new[14];
            // M[14]   <= M[13];

            // Q[15]   <= Q_new[15];
            // A[15]   <= A_new[15];
            // M[15]   <= M[14];
        end 
    end 

    wire [DATA_WIDTH-1:0] rem_abs;

    assign rem_abs      = (A[num_reg-1][DATA_WIDTH])    ? A[num_reg-1] + M[num_reg-1]   : A[num_reg-1];
    assign quotient     = (sign[num_reg - 1])           ? ~Q[num_reg - 1] + 1'b1        : Q[num_reg - 1];
    assign remainder    = (sign[num_reg - 1])           ? ~rem_abs + 1'b1               : rem_abs;

    DivStageK u_stage_first (
        .A_in({(DATA_WIDTH + 1){1'b0}}),
        .M_in(M0),
        .Q_in(abs_a),
        .A_out(A_new[0]),
        .Q_out(Q_new[0])
    );

    genvar gi;
    generate
        for (gi = 1 ; gi < 10; gi = gi + 1) begin : GEN_STAGES
            DivStageK stg(
                .A_in(A[gi - 1]),
                .M_in(M[gi - 1]),
                .Q_in(Q[gi - 1]),
                .A_out(A_new[gi]),
                .Q_out(Q_new[gi]) 
            );
        end
    endgenerate

    DivStageK #(.W(DATA_WIDTH), .K(2)) u_stage_last (
          .A_in  (A[9]),
          .M_in  (M[9]),
          .Q_in  (Q[9]),
          .A_out (A_new[10]),
          .Q_out (Q_new[10])
        );
    // DivStage2 DivStage2_inst0(
    //     .A_in(A[9]),
    //     .M_in(M[9]),
    //     .Q_in(Q[9]),
    //     .A_out(A_new[10]),
    //     .Q_out(Q_new[10]) 
    // );
endmodule