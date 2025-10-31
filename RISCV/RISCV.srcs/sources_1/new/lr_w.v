module lr_w (
    input         clk,
    input         rst_n,
    input         lr_en,
    input  [31:0] addr,
    input  [31:0] mem_rdata,
    input         mem_ready,
    output reg [31:0] rd_data,
    output        mem_req,
    output [31:0] mem_addr,
    output        lr_valid,
    output [31:0] lr_addr_out,
    output        lr_done,
    
    // AXI Read Address Channel
    output        axi_arvalid,
    input         axi_arready,
    output [31:0] axi_araddr,
    output [2:0]  axi_arsize,
    output [1:0]  axi_arlock,
    
    // AXI Read Data Channel
    input         axi_rvalid,
    output        axi_rready,
    input  [31:0] axi_rdata,
    input  [1:0]  axi_rresp
);

    localparam IDLE = 2'b00;
    localparam READ = 2'b01;
    localparam DONE = 2'b10;
    
    reg [1:0] state, next_state;
    reg [31:0] saved_addr;
    reg reservation_set;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always @(*) begin
        case (state)
            IDLE: next_state = lr_en ? READ : IDLE;
            READ: next_state = (axi_rvalid && axi_rready) ? DONE : READ;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            saved_addr <= 32'h0;
        else if (state == IDLE && lr_en)
            saved_addr <= addr;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_data <= 32'h0;
        else if (state == READ && axi_rvalid)
            rd_data <= axi_rdata;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reservation_set <= 1'b0;
        else if (state == READ && axi_rvalid)
            reservation_set <= 1'b1;
    end
    
    assign mem_req     = (state == READ);
    assign mem_addr    = saved_addr;
    assign lr_valid    = reservation_set;
    assign lr_addr_out = saved_addr;
    assign lr_done     = (state == DONE);
    
    // AXI Read Address Channel
    assign axi_arvalid = (state == READ);
    assign axi_araddr  = saved_addr;
    assign axi_arsize  = 3'b010;
    assign axi_arlock  = 2'b01;
    
    // AXI Read Data Channel
    assign axi_rready  = (state == READ);

endmodule
