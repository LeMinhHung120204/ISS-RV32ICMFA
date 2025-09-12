`timescale 1ns/1ps
module mul32 #(
    parameter DATA_WIDH = 32
)(
    input   clk, rst_n,
    input   is_unsigned,         
    input   [DATA_WIDH - 1:0] a, b,
    output  [(DATA_WIDH * 2) - 1:0] R, R_high
);
    localparam num_reg = 10;
    reg     [DATA_WIDH:0]           y_ext   [0:num_reg - 1];
    reg     [(DATA_WIDH * 2) - 1:0] result  [0:num_reg - 1];
    reg     [(DATA_WIDH * 2) - 1:0] regA    [0:num_reg - 1];
    wire    [(DATA_WIDH * 2) - 1:0] res     [0:num_reg - 1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < num_reg; i = i + 1'b1) begin
                y_ext[i]    <= 33'd0;
                result[i]   <= 64'd0;
                regA[i]     <= 64'd0;
            end 
        end 
        else begin
            y_ext[0] <= {b, 1'b0};
            regA[0]  <= (is_unsigned) ? {32'd0, a} : {{32{a[31]}}, a};

            y_ext[1] <= {3'b00, y_ext[0][DATA_WIDH:3]};
            regA[1]  <= regA[0] << 3;

            y_ext[2] <= {3'b00, y_ext[1][DATA_WIDH:3]};
            regA[2]  <= regA[1] << 3;

            y_ext[3] <= {3'b00, y_ext[2][DATA_WIDH:3]};
            regA[3]  <= regA[2] << 3;

            y_ext[4] <= {3'b00, y_ext[3][DATA_WIDH:3]};
            regA[4]  <= regA[3] << 3;

            y_ext[5] <= {3'b00, y_ext[4][DATA_WIDH:3]};
            regA[5]  <= regA[4] << 3;

            y_ext[6] <= {3'b00, y_ext[5][DATA_WIDH:3]};
            regA[6]  <= regA[5] << 3;

            y_ext[7] <= {3'b00, y_ext[6][DATA_WIDH:3]};
            regA[7]  <= regA[6] << 3;

            y_ext[8] <= {3'b00, y_ext[6][DATA_WIDH:3]};
            regA[8]  <= regA[7] << 3;

            y_ext[9] <= {3'b00, y_ext[6][DATA_WIDH:3]};
            regA[9]  <= regA[8] << 3;

            // save partial results
            result[0] <= res[0];
            result[1] <= res[1];
            result[2] <= res[2];
            result[3] <= res[3];
            result[4] <= res[4];
            result[5] <= res[5];
            result[6] <= res[6];
            result[7] <= res[7];
            result[8] <= res[8];
            result[9] <= res[9];
        end 
    end 

    // BoothDecode for stage 0 (first stage doesn't depend on result[-1])
    booth_decode booth0 (
        .R(64'd0),
        .A(regA[0]),
        .sel(y_ext[0][3:0]),
        .res(res[0])
    );

    genvar gi;
    generate
        for (gi = 1; gi < num_reg; gi = gi + 1) begin: booth_gen
            booth_decode booth_inst (
                .R(result[gi-1]),
                .A(regA[gi]),
                .sel(y_ext[gi][3:0]),
                .res(res[gi])
            );
        end
    endgenerate

    assign R        = result[9][31:0];
    assign R_high   = result[9][63:32];
endmodule