`timescale 1ns/1ps
module feq #(
    parameter WIDTH = 32
)(
    input                   clk,
    input                   rst_n,
    input                   valid_input,
    input   [WIDTH-1:0]     a,
    input   [WIDTH-1:0]     b,
    output  reg             valid_output,
    output  reg [WIDTH-1:0] y
);
    reg [2:0] state, next_state;
    localparam GET_INPUT=3'd0, UNPACK=3'd1, COMPARE=3'd2, PACK=3'd3, DONE=3'd4;

    reg [31:0] a_r, b_r;
    reg sa,sb; reg [7:0] ea,eb; reg [22:0] fa,fb;
    reg a_nan,b_nan,a_zero,b_zero;
    reg result;

    always @(posedge clk or negedge rst_n)
        if(!rst_n) state<=GET_INPUT; else state<=next_state;

    always @(*) begin
        next_state=state;
        case(state)
            GET_INPUT: if(valid_input) next_state=UNPACK;
            UNPACK   : next_state=COMPARE;
            COMPARE  : next_state=PACK;
            PACK     : next_state=DONE;
            DONE     : next_state=GET_INPUT;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin a_r<=0; b_r<=0; end
        else if(valid_input && state==GET_INPUT) begin a_r<=a; b_r<=b; end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sa<=0;sb<=0;ea<=0;eb<=0;fa<=0;fb<=0; end
        else if(state==UNPACK) begin
            sa<=a_r[31]; sb<=b_r[31];
            ea<=a_r[30:23]; eb<=b_r[30:23];
            fa<=a_r[22:0];  fb<=b_r[22:0];
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin a_nan<=0;b_nan<=0;a_zero<=0;b_zero<=0; end
        else if(state==UNPACK) begin
            a_nan <= (ea==8'hFF && fa!=0);  b_nan <= (eb==8'hFF && fb!=0);
            a_zero<= (ea==8'h00 && fa==0);  b_zero<= (eb==8'h00 && fb==0);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) result<=0;
        else if(state==COMPARE) begin
            if(a_nan || b_nan) result <= 1'b0;
            else if(a_zero && b_zero) result <= 1'b1; // +0 == -0
            else result <= (a_r == b_r);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) y<=0;
        else if(state==PACK) y <= {31'b0, result};
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) valid_output<=0;
        else       valid_output <= (state==DONE);
    end
endmodule
