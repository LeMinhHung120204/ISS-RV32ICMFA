module ICache(
    input         clk,
    input         reset,
    input         req_valid,          // Có yêu cầu fetch
    input  [31:0] req_addr,           // Địa chỉ PC
    output        resp_valid,         // Có dữ liệu hợp lệ
    output [31:0] resp_data,          // Dữ liệu lệnh
    output        hit                 // Có cache hit không
    output       req_ready,          // Sẵn sàng nhận yêu cầu mới
);
    reg [22:0] ram_tag1 [0:255];
    reg [22:0] ram_tag2 [0:255];
    reg [22:0] ram_tag3 [0:255];
    reg [22:0] ram_tag4 [0:255];

    reg [31:0] data1 [0:255];
    reg [31:0] data2 [0:255];
    reg [31:0] data3 [0:255];
    reg [31:0] data4 [0:255];

    // S0: Nhận yêu cầu
    reg        s0_valid;
    reg [31:0] s0_addr;
    
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            s0_valid <= 1'b0;
            s0_addr  <= 32'b0;
        end else if (req_valid && req_ready) begin
            s0_valid <= req_valid;
            s0_addr  <= req_addr;
        end
    end

    // S1: Decode
    reg        s1_valid;
    reg [31:0] s1_paddr;
    reg [19:0] s1_tag;
    reg [5:0]  s1_idx;

    always @(posedge clk) begin
        s1_valid <= s0_valid;
        s1_idx   <= s0_addr[9:2];  // 6 bit index
        s1_tag   <= s0_addr[31:10]; // 22 bit tag
    end

    // S2: Compare
    reg s2_valid;
    reg s2_hit;
    reg [31:0] s2_data;
    wire hit1, hit2, hit3, hit4;

    assign hit1 = (ram_tag1[s1_idx][22:1] == req_addr[31:10]) && ram_tag1[s1_idx][0];
    assign hit2 = (ram_tag2[s1_idx][22:1] == req_addr[31:10]) && ram_tag2[s1_idx][0];
    assign hit3 = (ram_tag3[s1_idx][22:1] == req_addr[31:10]) && ram_tag3[s1_idx][0];
    assign hit4 = (ram_tag4[s1_idx][22:1] == req_addr[31:10]) && ram_tag4[s1_idx][0];

    wire [31:0] way_sel = hit1 ? data1[s1_idx] :
                         hit2 ? data2[s1_idx] :
                         hit3 ? data3[s1_idx]:
                         hit4 ? data4[s1_idx] : 2'd0;

    assign hit_comb = hit1 | hit2 | hit3 | hit4;

    always @(posedge clk) begin
        s2_valid <= s1_valid;
        s2_hit   <= hit_comb;
        s2_data   <= way_sel;
    end

    // S3: Read data
    reg s3_valid;
    reg s3_hit;
    reg [31:0] s3_data;

    always @(posedge clk) begin
        s3_valid <= s2_valid;
        s3_hit   <= s2_hit;
        if (s2_hit) begin
            s3_data <= s2_data; // Lấy dữ liệu từ cache hit
        end else begin
            s3_data <= 32'b0; // Không có dữ liệu hợp lệ
        end
    end

    // S4: Output
    reg s4_valid;
    reg [31:0] s4_data;
    reg s4_hit;

    always @(posedge clk) begin
        s4_valid <= s3_valid;
        s4_data  <= s3_data;
        s4_hit   <= s3_hit;
    end

    reg refill_valid;
    
    assign resp_valid = s4_valid;
    assign resp_data  = s4_data;
    assign hit = s4_hit;
    assign req_ready = ~refill_valid;
endmodule