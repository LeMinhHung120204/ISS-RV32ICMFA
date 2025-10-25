module sc_w (
    input         clk,
    input         rst_n,
    input         sc_en,
    input  [31:0] addr,
    input  [31:0] wdata,
    input         rsv_valid,
    input  [31:0] rsv_addr,
    input         mem_ready,
    output reg [31:0] rd_data,
    output        mem_req,
    output [31:0] mem_addr,
    output        mem_we,
    output [31:0] mem_wdata,
    output        sc_done
);

    localparam IDLE  = 2'b00;
    localparam CHECK = 2'b01;
    localparam WRITE = 2'b10;
    localparam DONE  = 2'b11;

    reg [1:0] state, next_state;
    reg [31:0] saved_addr;
    reg [31:0] saved_wdata;
    reg success_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:  next_state = sc_en ? CHECK : IDLE;
            CHECK: next_state = (rsv_valid && (rsv_addr == addr)) ? WRITE : DONE;
            WRITE: next_state = mem_ready ? DONE : WRITE;
            DONE:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saved_addr  <= 32'h0;
            saved_wdata <= 32'h0;
        end else if (state == IDLE && sc_en) begin
            saved_addr  <= addr;
            saved_wdata <= wdata;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            success_flag <= 1'b0;
        else if (state == CHECK)
            success_flag <= (rsv_valid && (rsv_addr == addr));
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_data <= 32'h0;
        else if (state == CHECK && !(rsv_valid && (rsv_addr == addr)))
            rd_data <= 32'h1; // thất bại
        else if (state == WRITE && mem_ready)
            rd_data <= 32'h0; // thành công
    end

    assign mem_req   = (state == WRITE);
    assign mem_addr  = saved_addr;
    assign mem_we    = (state == WRITE);
    assign mem_wdata = saved_wdata;
    assign sc_done   = (state == DONE);

endmodule
