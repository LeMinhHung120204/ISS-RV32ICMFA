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
    output        sc_done,
    
    // AXI Write Address Channel
    output        axi_awvalid,
    input         axi_awready,
    output [31:0] axi_awaddr,
    output [2:0]  axi_awsize,
    output [1:0]  axi_awlock,
    
    // AXI Write Data Channel
    output        axi_wvalid,
    input         axi_wready,
    output [31:0] axi_wdata,
    output [3:0]  axi_wstrb,
    
    // AXI Write Response Channel
    input         axi_bvalid,
    output        axi_bready,
    input  [1:0]  axi_bresp
);

    localparam IDLE  = 2'b00;
    localparam CHECK = 2'b01;
    localparam WRITE = 2'b10;
    localparam DONE  = 2'b11;

    reg [1:0] state, next_state;
    reg [31:0] saved_addr;
    reg [31:0] saved_wdata;

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
            WRITE: next_state = (axi_bvalid && axi_bready) ? DONE : WRITE;
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
            rd_data <= 32'h0;
        else if (state == CHECK && !(rsv_valid && (rsv_addr == addr)))
            rd_data <= 32'h1;
        else if (state == WRITE && axi_bvalid)
            rd_data <= 32'h0;
    end

    assign mem_req   = (state == WRITE);
    assign mem_addr  = saved_addr;
    assign mem_we    = (state == WRITE);
    assign mem_wdata = saved_wdata;
    assign sc_done   = (state == DONE);
    
    // AXI Write Address Channel
    assign axi_awvalid = (state == WRITE);
    assign axi_awaddr  = saved_addr;
    assign axi_awsize  = 3'b010;
    assign axi_awlock  = 2'b01;
    
    // AXI Write Data Channel
    assign axi_wvalid  = (state == WRITE);
    assign axi_wdata   = saved_wdata;
    assign axi_wstrb   = 4'b1111;
    
    // AXI Write Response Channel
    assign axi_bready  = (state == WRITE);

endmodule
