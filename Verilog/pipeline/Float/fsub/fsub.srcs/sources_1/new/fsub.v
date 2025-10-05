`timescale 1ns/1ps
module fsub #(
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
    reg [3:0] state, next_state;
    localparam GET_INPUT=4'd0, UNPACK=4'd1, SPECIAL=4'd2, ALIGN=4'd3,
               ADD_SUB=4'd4, NORMALIZE=4'd5, PACK=4'd6, DONE=4'd7;

    reg [31:0] a_r, b_r;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin a_r<=0; b_r<=0; end
        else if(valid_input && state==GET_INPUT) begin a_r<=a; b_r<=b; end
    end

    always @(posedge clk or negedge rst_n)
        if(!rst_n) state<=GET_INPUT; else state<=next_state;

    always @(*) begin
        next_state=state;
        case(state)
            GET_INPUT: if(valid_input) next_state=UNPACK;
            UNPACK   : next_state=SPECIAL;
            SPECIAL  : next_state=ALIGN;
            ALIGN    : next_state=ADD_SUB;
            ADD_SUB  : next_state=NORMALIZE;
            NORMALIZE: next_state=PACK;
            PACK     : next_state=DONE;
            DONE     : next_state=GET_INPUT;
        endcase
    end

    // fields
    reg sa,sb; reg [7:0] ea,eb; reg [22:0] fa,fb;
    reg a_nan,b_nan,a_inf,b_inf,a_zero,b_zero;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sa<=0;sb<=0;ea<=0;eb<=0;fa<=0;fb<=0; end
        else if(state==UNPACK) begin
            sa<=a_r[31]; sb<=b_r[31];
            ea<=a_r[30:23]; eb<=b_r[30:23];
            fa<=a_r[22:0];  fb<=b_r[22:0];
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin a_nan<=0;b_nan<=0;a_inf<=0;b_inf<=0;a_zero<=0;b_zero<=0; end
        else if(state==UNPACK) begin
            a_nan <= (ea==8'hFF && fa!=0);  b_nan <= (eb==8'hFF && fb!=0);
            a_inf <= (ea==8'hFF && fa==0);  b_inf <= (eb==8'hFF && fb==0);
            a_zero<= (ea==8'h00 && fa==0);  b_zero<= (eb==8'h00 && fb==0);
        end
    end

    // specials
    reg special_case; reg [31:0] special_y;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin special_case<=0; special_y<=0; end
        else if(state==SPECIAL) begin
            special_case <= 1'b1;
            if(a_nan || b_nan)                 special_y <= {1'b0,8'hFF,23'h400000};
            else if(a_inf && b_inf) begin
                if(sa==sb)                     special_y <= {1'b0,8'hFF,23'h400000};
                else                           special_y <= {sa,8'hFF,23'h000000};
            end else if(a_inf)                 special_y <= {sa,8'hFF,23'h000000};
            else if(b_inf)                     special_y <= {~sb,8'hFF,23'h000000};
            else if(a_zero && b_zero)          special_y <= 32'h00000000;
            else if(b_zero)                    special_y <= {sa,ea,fa};
            else if(a_zero)                    special_y <= {~sb,eb,fb};
            else                               special_case <= 1'b0;
        end
    end

    // align
    reg [26:0] ma,mb,ma_s,mb_s,msum;
    reg [8:0]  exp_big, eres;
    reg sres, use_sub;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin ma<=0;mb<=0;ma_s<=0;mb_s<=0;exp_big<=0;sres<=0;use_sub<=0; end
        else if(state==ALIGN) begin
            // a - b = a + (-b) ⇒ sau khi lật dấu b, phép toán magnitude là trừ nếu sa==sb
            use_sub <= (sa==sb);
            ma <= {4'b0001, fa, 1'b0};
            mb <= {4'b0001, fb, 1'b0};
            if(ea>=eb) begin
                exp_big <= {1'b0,ea};
                ma_s <= ma;
                mb_s <= (ea==eb) ? mb : (mb >> (ea-eb));
                sres <= sa;
            end else begin
                exp_big <= {1'b0,eb};
                mb_s <= mb;
                ma_s <= (ea==eb) ? ma : (ma >> (eb-ea));
                sres <= ~sb;
            end
        end
    end

    // add/sub
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin msum<=0; eres<=0; end
        else if(state==ADD_SUB) begin
            eres <= exp_big;
            if(use_sub) begin
                if(ma_s>=mb_s) msum <= ma_s - mb_s;
                else begin msum <= mb_s - ma_s; sres <= ~sres; end
            end else msum <= ma_s + mb_s;
        end
    end

    // normalize (đơn giản cho mô phỏng)
    reg [26:0] nm; reg [8:0] ne;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin nm<=0; ne<=0; end
        else if(state==NORMALIZE) begin
            nm<=msum; ne<=eres;
            if(msum[26]) begin nm <= {1'b0,msum[26:1]}; ne <= eres + 1'b1; end
            else if(msum!=0) begin
                while(nm[26]==1'b0 && ne>0) begin nm<=nm<<1; ne<=ne-1'b1; end
            end
        end
    end

    // pack
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) y<=0;
        else if(state==PACK) begin
            if(special_case)       y <= special_y;
            else if(nm==0)         y <= 32'h00000000;
            else                   y <= {sres, ne[7:0], nm[25:3]}; // lấy 23 bit frac
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) valid_output<=0;
        else       valid_output <= (state==DONE);
    end
endmodule
