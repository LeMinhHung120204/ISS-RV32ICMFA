module amoxor_w (
    input         clk, rst_n, valid_input,
    input  [31:0] rs1,
    input  [31:0] rs2,
    input  [31:0] mem_rdata,
    output reg    valid_output,
    output reg [31:0] rd,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    
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
    input  [1:0]  axi_rresp,
    
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

    localparam IDLE = 2'b00, READ = 2'b01, ALU = 2'b10, WRITE = 2'b11;
    
    reg [1:0] state, next_state;
    reg [31:0] rs1_r, rs2_r, rdata_r, result_r;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (valid_input) next_state = READ;
            READ: if (axi_rvalid && axi_rready) next_state = ALU;
            ALU:  next_state = WRITE;
            WRITE: if (axi_bvalid && axi_bready) next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rs1_r <= 0; rs2_r <= 0;
        end else if (state == IDLE && valid_input) begin
            rs1_r <= rs1;
            rs2_r <= rs2;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rdata_r <= 0;
        else if (state == READ && axi_rvalid)
            rdata_r <= axi_rdata;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) result_r <= 0;
        else if (state == ALU)
            result_r <= rdata_r ^ rs2_r;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_output <= 0;
            rd <= 0;
            mem_addr <= 0;
            mem_wdata <= 0;
        end else if (state == WRITE && axi_bvalid) begin
            valid_output <= 1;
            rd <= rdata_r;
            mem_addr <= rs1_r;
            mem_wdata <= result_r;
        end else begin
            valid_output <= 0;
        end
    end
    
    // AXI Read
    assign axi_arvalid = (state == READ);
    assign axi_araddr = rs1_r;
    assign axi_arsize = 3'b010;
    assign axi_arlock = 2'b01;
    assign axi_rready = (state == READ);
    
    // AXI Write
    assign axi_awvalid = (state == WRITE);
    assign axi_awaddr = rs1_r;
    assign axi_awsize = 3'b010;
    assign axi_awlock = 2'b01;
    assign axi_wvalid = (state == WRITE);
    assign axi_wdata = result_r;
    assign axi_wstrb = 4'b1111;
    assign axi_bready = (state == WRITE);

endmodule
