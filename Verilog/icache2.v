module icache2 #(
    parameter NUM_SETS = 64,
    parameter NUM_WAYS = 4,
    parameter OFFSET_BITS = 6,   // 64B
    parameter INDEX_BITS  = 6,   // 64 sets
    parameter TAG_BITS    = 32 - OFFSET_BITS - INDEX_BITS // 10 bits
)(
    input         clk, rst_n,
    input         req_valid, // yêu cầu từ CPU
    input  [31:0] req_addr,  // địa chỉ yêu cầu từ CPU
    output        req_ready, // sẵn sàng nhận yêu cầu từ CPU

    // mem IF (đơn giản: yêu cầu 1 word; nếu line-fill thì thay đổi)
    output        mem_req_valid,    // yêu cầu từ cache đến memory
    output [31:0] mem_req_addr,     // địa chỉ yêu cầu từ cache đến memory
    input         mem_resp_valid,   // phản hồi từ memory
    input  [31:0] data_in,          // dữ liệu trả về từ memory

    output        resp_valid,       // phản hồi từ cache đến CPU
    output reg [31:0] resp_data,        // dữ liệu trả về từ cache đến CPU
    output        hit               // hit signal indicating cache hit
);

    parameter [1:0] IDLE = 2'b00, CHECK_TAG = 2'b01, FILL = 2'b10;
    reg [1:0] state, next_state;

    // Tag/Valid/Data arrays
    reg [TAG_BITS-1:0]  tag_array   [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg                 valid_array [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [511:0]         data_array  [0:NUM_WAYS-1][0:NUM_SETS-1];

    // pseudo-LRU tree for 4-way
    reg [2:0] plru [0:NUM_SETS-1];

    // Phân tách địa chỉ
    wire [INDEX_BITS-1:0] index    = req_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    wire [TAG_BITS-1:0]   tag      = req_addr[31 -: TAG_BITS];
    wire [3:0]            word_off = req_addr[5:2]; // 0..15 trong line 64B

    // HIT detection
    wire [NUM_WAYS-1:0] way_hit;
    assign way_hit[0] = valid_array[0][index] & (tag_array[0][index] == tag);
    assign way_hit[1] = valid_array[1][index] & (tag_array[1][index] == tag);
    assign way_hit[2] = valid_array[2][index] & (tag_array[2][index] == tag);
    assign way_hit[3] = valid_array[3][index] & (tag_array[3][index] == tag);
    assign hit          = |way_hit;

    // Way vừa hit (để update PLRU)
    wire        hit_way_valid = hit;
    wire [1:0]  hit_way = way_hit[0] ? 2'd0 :
                          way_hit[1] ? 2'd1 :
                          way_hit[2] ? 2'd2 : 2'd3;

    // Miss context
    reg [31:0]           miss_addr;
    reg [INDEX_BITS-1:0] miss_index;
    reg [TAG_BITS-1:0]   miss_tag;
    reg [3:0]            miss_word_off;

    // Burst state
    reg        filling;
    reg [1:0]  fill_way;
    reg [3:0]  beat_cnt;
    reg [3:0]  cur_off;
    wire [31:0] line_base = {miss_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state) 
            IDLE:       next_state = (req_valid == 1'b1) ? CHECK_TAG : IDLE;
            CHECK_TAG:  next_state = (hit == 1'b1) ? IDLE : FILL;
            FILL:       next_state = (mem_resp_valid & (beat_cnt==4'd15)) ? IDLE : FILL;
            default:    next_state = IDLE;
        endcase
    end 

    // Ready/valid
    assign req_ready  = (state == IDLE);
    // Khi hit: phản hồi trong CHECK_TAG
    // Khi fill: phản hồi ngay ở beat có off == miss_word_off
    wire resp_on_fill = (state == FILL) & mem_resp_valid & (cur_off == miss_word_off);
    assign resp_valid = (state==CHECK_TAG & hit) | resp_on_fill;

    // Data out
    always @(*) begin
        if ((state == CHECK_TAG) & hit) begin
            case (1'b1)
                way_hit[0]: resp_data = data_array[0][index][(word_off*32) +: 32];
                way_hit[1]: resp_data = data_array[1][index][(word_off*32) +: 32];
                way_hit[2]: resp_data = data_array[2][index][(word_off*32) +: 32];
                way_hit[3]: resp_data = data_array[3][index][(word_off*32) +: 32];
                default:    resp_data = 32'b0;
            endcase
        end 
        else begin
            resp_data = data_in; // trong fill, đúng beat sẽ valid
        end
    end

    // LRU chọn victim
    wire [1:0] lru_way;
    plru_lookup u_plru_lkp (.plru(plru[index]), .lru_way(lru_way));
    wire [1:0] victim_way = lru_way;

    // Latch miss info khi chuyển sang FILL
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            miss_addr     <= 32'b0;
            miss_index    <= {INDEX_BITS{1'b0}};
            miss_tag      <= {TAG_BITS{1'b0}};
            miss_word_off <= 4'd0;
            fill_way      <= 2'd0;
        end 
        else if ((state==CHECK_TAG) & req_valid & (~hit)) begin
            miss_addr     <= req_addr;
            miss_index    <= index;
            miss_tag      <= tag;
            miss_word_off <= word_off;
            fill_way      <= victim_way;
        end
    end

    // Điều khiển burst fill (critical-word-first + wrap)
    // cur_off bắt đầu tại miss_word_off, tăng và wrap qua 16
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            filling  <= 1'b0;
            beat_cnt <= 4'd0;
            cur_off  <= 4'd0;
        end 
        else begin
            if ((state == CHECK_TAG) & req_valid & (~hit)) begin
                filling  <= 1'b1;
                beat_cnt <= 4'd0;
                cur_off  <= miss_word_off;
            end else if (state == FILL) begin
                if (mem_resp_valid) begin
                    beat_cnt <= beat_cnt + 4'd1;
                    cur_off  <= cur_off + 4'd1;
                    if (beat_cnt == 4'd15) filling <= 1'b0;
                end
            end
        end
    end

    // Memory requests (chỉ GIỮ bản line-fill; xóa bản 1-word)
    assign mem_req_valid = (state == FILL) | ((state==CHECK_TAG) & req_valid & (~hit));
    assign mem_req_addr  = ((state == CHECK_TAG) & req_valid & (~hit)) ?
                           ({req_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}} + {{26{1'b0}}, word_off, 2'b00}) :
                           (state == FILL) ?
                           (line_base + {{26{1'b0}}, cur_off, 2'b00}) : 32'b0;

    // PLRU update modules
    wire [2:0] plru_new_hit, plru_new_fill;
    plru_update u_plru_upd_hit  (.plru_in(plru[index]),      .way_access(hit_way),  .plru_out(plru_new_hit));
    plru_update u_plru_upd_fill (.plru_in(plru[miss_index]), .way_access(fill_way), .plru_out(plru_new_fill));


    // Write arrays + update PLRU
    integer si;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (si = 0; si < NUM_SETS; si = si + 1'b1) begin
                plru[si] <= 3'b000;
                valid_array[0][si] <= 1'b0; data_array [0][si] <= 512'b0; tag_array[0][si] <= {TAG_BITS{1'b0}};
                valid_array[1][si] <= 1'b0; data_array [1][si] <= 512'b0; tag_array[1][si] <= {TAG_BITS{1'b0}};
                valid_array[2][si] <= 1'b0; data_array [2][si] <= 512'b0; tag_array[2][si] <= {TAG_BITS{1'b0}};
                valid_array[3][si] <= 1'b0; data_array [3][si] <= 512'b0; tag_array[3][si] <= {TAG_BITS{1'b0}};
            end
        end else begin
            // HIT: update PLRU set hiện tại
            if ((state == CHECK_TAG) & hit_way_valid)
                plru[index] <= plru_new_hit;

            // FILL: ghi từng beat vào line
            if ((state == FILL) & mem_resp_valid) begin
                data_array[fill_way][miss_index][(cur_off*32) +: 32] <= data_in;
                if (beat_cnt == 4'd15) begin
                    tag_array [fill_way][miss_index]  <= miss_tag;
                    valid_array[fill_way][miss_index] <= 1'b1;
                    plru[miss_index]                  <= plru_new_fill;
                end
            end
        end
    end
endmodule