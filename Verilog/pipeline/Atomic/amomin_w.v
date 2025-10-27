module amomin_w (
    input         clk, rst_n, valid_input,
    input  [31:0] rs1,
    input  [31:0] rs2,
    input  [31:0] mem_rdata,
    output reg    valid_output,
    output reg [31:0] rd,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata
);
    reg v0;
    reg [31:0] addr0, src0, mem0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v0 <= 0; addr0 <= 0; src0 <= 0; mem0 <= 0;
        end else begin
            v0 <= valid_input;
            addr0 <= rs1;
            src0 <= rs2;
            mem0 <= mem_rdata;
        end
    end

    reg v1;
    reg [31:0] addr1, rd1, wdata1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1 <= 0; addr1 <= 0; rd1 <= 0; wdata1 <= 0;
        end else begin
            v1 <= v0;
            addr1 <= addr0;
            rd1 <= mem0;
            wdata1 <= ($signed(mem0) < $signed(src0)) ? mem0 : src0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_output <= 0;
            rd <= 0;
            mem_addr <= 0;
            mem_wdata <= 0;
        end else begin
            valid_output <= v1;
            rd <= rd1;
            mem_addr <= addr1;
            mem_wdata <= wdata1;
        end
    end
endmodule
