`timescale 1ns/1ps
module non_restore #(
    parameter DATA_WIDTH = 32
)(
    input   clk, rst_n, is_unsigned, valid_input,
    input   [DATA_WIDTH - 1:0] dividend, divisor,
    output  [DATA_WIDTH - 1:0] quotient, remainder,
    output  valid_output,
    output  reg is_busy
);
    localparam IDLE = 0, INIT = 1, CALC = 2, DONE = 3;
    localparam num_reg = 17;
    localparam num_tmp = 17;

    reg [1:0]               state;
    reg [DATA_WIDTH-1:0]    reg_a, reg_b;
    reg [DATA_WIDTH:0]      M;
    reg [DATA_WIDTH:0]      A, A_res;
    reg [DATA_WIDTH-1:0]    Q, Q_res;
    reg                     sign;
    reg [4:0]               count_calc;

    wire [DATA_WIDTH:0]     A_new [0:1];
    wire [DATA_WIDTH-1:0]   Q_new [0:1];
    wire [DATA_WIDTH:0]     divisor_ex;

    wire sign_a;
    wire sign_b;
    wire [DATA_WIDTH-1:0] abs_a, abs_b;
    wire [DATA_WIDTH:0] M0;

    assign divisor_ex   = (is_unsigned) ? {1'b0, reg_b} : {reg_b[DATA_WIDTH-1], reg_b};
    assign sign_a       = ~is_unsigned & reg_a[DATA_WIDTH-1];
    assign sign_b       = ~is_unsigned & reg_b [DATA_WIDTH-1];
    assign abs_a        = sign_a ? (~reg_a + 1'b1) : reg_a;
    assign abs_b        = sign_b ? (~reg_b  + 1'b1) : reg_b;
    assign M0           = {1'b0, abs_b};

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1) begin
                Q[i] <= {DATA_WIDTH{1'b0}};
                M[i] <= {(DATA_WIDTH + 1){1'b0}};
                A[i] <= {(DATA_WIDTH + 1){1'b0}};
            end 
            A           <= {(DATA_WIDTH + 1){1'b0}};
            A_res       <= {(DATA_WIDTH + 1){1'b0}};
            M           <= {(DATA_WIDTH + 1){1'b0}};
            reg_a       <= {(DATA_WIDTH){1'b0}};
            reg_b       <= {(DATA_WIDTH){1'b0}};
            Q           <= {DATA_WIDTH{1'b0}};
            Q_res       <= {DATA_WIDTH{1'b0}};
            state       <= IDLE;
            count_calc  <= 5'd0;
            is_busy     <= 1'b0;
            sign        <= 1'b0;
        end 
        else begin
            case(state)
                IDLE: begin
                    A       <= {(DATA_WIDTH + 1){1'b0}};
                    reg_a   <= {(DATA_WIDTH){1'b0}};
                    reg_b   <= {(DATA_WIDTH){1'b0}};
                    Q       <= {DATA_WIDTH{1'b0}};
                    is_busy <= 1'b0;
                    if (valid_input) begin
                        reg_a   <= dividend;
                        reg_b   <= divisor;
                        state   <= INIT;
                        is_busy <= 1'b1;
                        
                    end 
                end
                INIT: begin
                    M       <= M0;
                    Q       <= abs_a;
                    sign    <= sign_a ^ sign_b;
                    state   <= CALC;
                end 
                CALC: begin
                    count_calc  <= count_calc + 1'b1;
                    if (count_calc == 5'd0) begin
                        A   <= A_new[0];
                        Q   <= Q_new[0];
                    end
                    else if (count_calc <= 5'd15) begin
                        A   <= A_new[1];
                        Q   <= Q_new[1];
                    end
                    else begin
                        A_res   <= A_new[0];
                        Q_res   <= Q_new[0];
                        state   <= DONE;
                    end
                end
                DONE: begin
                    count_calc  <= 5'd0;
                    is_busy     <= 1'b0;
                    state       <= IDLE;
                end
            endcase
            // sign    <= {sign[num_reg-2:0], sign_a ^ sign_b};
            // hold_valid  <= {hold_valid[15:0], valid_input};

            // Q[0]    <= Q_new[0];
            // A[0]    <= A_new[0];
            // M[0]    <= M0;

            // Q[1]    <= Q_new[1];
            // A[1]    <= A_new[1];
            // M[1]    <= M[0];

            // Q[2]    <= Q_new[2];
            // A[2]    <= A_new[2];
            // M[2]    <= M[1];

            // Q[3]    <= Q_new[3];
            // A[3]    <= A_new[3];
            // M[3]    <= M[2];

            // Q[4]    <= Q_new[4];
            // A[4]    <= A_new[4];
            // M[4]    <= M[3];

            // Q[5]    <= Q_new[5];
            // A[5]    <= A_new[5];
            // M[5]    <= M[4];

            // Q[6]    <= Q_new[6];
            // A[6]    <= A_new[6];
            // M[6]    <= M[5];

            // Q[7]    <= Q_new[7];
            // A[7]    <= A_new[7];
            // M[7]    <= M[6];

            // Q[8]    <= Q_new[8];
            // A[8]    <= A_new[8];
            // M[8]    <= M[7];

            // Q[9]    <= Q_new[9];
            // A[9]    <= A_new[9];
            // M[9]    <= M[8];

            // Q[10]   <= Q_new[10];
            // A[10]   <= A_new[10];
            // M[10]   <= M[9];

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

            // Q[16]   <= Q_new[16];
            // A[16]   <= A_new[16];
            // M[16]   <= M[15];
        end 
    end 

    // wire [DATA_WIDTH-1:0] rem_abs;

    // assign rem_abs      = (A[num_reg-1][DATA_WIDTH])    ? A[num_reg-1] + M[num_reg-1]   : A[num_reg-1];
    // assign quotient     = (sign[num_reg - 1])           ? ~Q[num_reg - 1] + 1'b1        : Q[num_reg - 1];
    // assign remainder    = (sign[num_reg - 1])           ? ~rem_abs + 1'b1               : rem_abs;
    // assign valid_output = hold_valid[16];


    
    wire [DATA_WIDTH-1:0] rem_abs;

    assign rem_abs      = (A_res[DATA_WIDTH])   ? A_res + M         : A_res;
    assign quotient     = (sign)                ? ~Q_res + 1'b1     : Q_res;
    assign remainder    = (sign)                ? ~rem_abs + 1'b1   : rem_abs;
    assign valid_output = (state == DONE);

    Div_unit u_stage_first (
        .A(A),
        .M(M),
        .Q(Q),
        .A_new(A_new[0]),
        .Q_new(Q_new[0])
    );

    DivStageK #(.W(DATA_WIDTH), .K(2)) stg(
        .A_in(A),
        .M_in(M),
        .Q_in(Q),
        .A_out(A_new[1]),
        .Q_out(Q_new[1]) 
    );

    // genvar gi;
    // generate
    //     for (gi = 1 ; gi < 16; gi = gi + 1) begin : GEN_STAGES
    //         DivStageK #(.W(DATA_WIDTH), .K(2)) stg(
    //             .A_in(A[gi - 1]),
    //             .M_in(M[gi - 1]),
    //             .Q_in(Q[gi - 1]),
    //             .A_out(A_new[gi]),
    //             .Q_out(Q_new[gi]) 
    //         );
    //     end
    // endgenerate

    // Div_unit u_stage_last (
    //     .A(A[15]),
    //     .M(M[15]),
    //     .Q(Q[15]),
    //     .A_new(A_new[16]),
    //     .Q_new(Q_new[16])
    // );

    // Div_unit u_stage_last (
    //     .A(A),
    //     .M(M),
    //     .Q(Q),
    //     .A_new(A_new[2]),
    //     .Q_new(Q_new[2])
    // );
endmodule