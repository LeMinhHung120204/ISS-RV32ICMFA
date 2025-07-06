module ICache(
    input clk, reset,
    input req_valid,            // Có yêu cầu fetch
    input [31:0] req_addr,      // Địa chỉ PC
    output resp_valid,          // Có dữ liệu hợp lệ
    output [31:0] resp_data,    // Dữ liệu lệnh
    output hit,                 // Có cache hit không
    output req_ready,           // Sẵn sàng nhận yêu cầu mới
);
    typedef enum logic [1:0] {
        IDLE,
        REQ,   // gửi request đến memory
        WAIT,  // đợi memory trả lời
        FILL   // ghi dữ liệu vào cache
    } refill_state_t;

    reg [1:0] refill_state;
    reg [31:0] refill_addr;
    reg [31:0] refill_data;

    reg [22:0] ram_tag1 [0:255];
    reg [22:0] ram_tag2 [0:255];
    reg [22:0] ram_tag3 [0:255];
    reg [22:0] ram_tag4 [0:255];

    reg [31:0] data1 [0:255];
    reg [31:0] data2 [0:255];
    reg [31:0] data3 [0:255];
    reg [31:0] data4 [0:255];

    reg [5:0]  idx;  // 6 bit index
    reg [21:0] tag;  // 22 bit tag
    
    wire hit1, hit2, hit3, hit4;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            idx <= 0;
            tag <= 0;
        end else if (req_valid && req_ready) begin
            idx   <= req_addr[9:2];  // 6 bit index
            tag   <= req_addr[31:10]; // 22 bit tag
        end
    end

    assign hit1 = (ram_tag1[idx][22:1] == req_addr[31:10]) && ram_tag1[idx][0];
    assign hit2 = (ram_tag2[idx][22:1] == req_addr[31:10]) && ram_tag2[idx][0];
    assign hit3 = (ram_tag3[idx][22:1] == req_addr[31:10]) && ram_tag3[idx][0];
    assign hit4 = (ram_tag4[idx][22:1] == req_addr[31:10]) && ram_tag4[idx][0];

    wire [31:0] way_sel = hit1 ? data1[idx] :
                         hit2 ? data2[idx] :
                         hit3 ? data3[idx]:
                         hit4 ? data4[idx] : 2'd0;

    assign hit = hit1 | hit2 | hit3 | hit4;
    reg refill_valid;
    
    assign resp_valid = hit | refill_valid;
    assign resp_data  = (hit) ? way_sel : 32'b0;
    assign req_ready = ~refill_valid;
endmodule