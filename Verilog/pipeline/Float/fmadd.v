module fmadd #(
    parameter WIDTH = 32
)(
    input   clk, rst_n, valid_input,
    input   [WIDTH-1:0] rs1, rs2, rs3,
    output  [WIDTH-1:0] rd,
    output  valid_output
);
    reg     [WIDTH-1:0] reg_rs1, reg_rs2, reg_rs3;
    reg     reg_ivalid;

    wire    [WIDTH-1:0] res_mul;
    wire    mul_done;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_rs1     <= 32'd0;
            reg_rs2     <= 32'd0;
            reg_rs3     <= 32'd0;
            reg_ivalid  <= 1'b0;
        end
        else begin
            reg_ivalid  <= valid_input;
            if (valid_input) begin
                reg_rs1 <= rs1;
                reg_rs2 <= rs2;
                reg_rs3 <= rs3;
            end
        end 
    end 

    fmul fmul_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(reg_ivalid),
        .a(reg_rs1),
        .b(reg_rs2),
        .valid_output(mul_done),
        .y(res_mul)
    );

    fadd fadd_inst(
        .clk(clk),
        .rst_n(rst_n),
        .valid_input(mul_done),
        .a(res_mul),
        .b(reg_rs3),
        .valid_output(valid_output),
        .y(rd)
    );
endmodule