module icache2 #(
    parameter NUM_SETS    = 64,
    parameter NUM_WAYS    = 4,
    parameter OFFSET_BITS = 6,    // 64B
    parameter INDEX_BITS  = 6,    // 64 sets
    parameter TAG_BITS    = 32 - OFFSET_BITS - INDEX_BITS
)(
    input         clk, rst_n,

    // CPU side
    input         req_valid,        // CPU đưa yêu cầu (giữ 1 tới khi req_ready=1)
    input  [31:0] req_addr,         // ổn định khi req_valid=1 && req_ready=0
    output        req_ready,        // cache sẵn sàng nhận

    input         resp_ready,       // CPU sẵn sàng nhận dữ liệu
    output        resp_valid,       // cache đang có dữ liệu hợp lệ
    output [31:0] resp_data,        // dữ liệu trả về (hợp lệ khi resp_valid=1)

    // Memory side (read-only; burst 16 beat)
    input         mem_req_ready,    // ARREADY
    output        mem_req_valid,    // ARVALID
    output [31:0] mem_req_addr,     // ARADDR (base hoặc critical-first offset)

    input         mem_resp_valid,   // RVALID
    input  [31:0] mem_resp_data,    // RDATA
    input         mem_resp_last,    // RLAST
    output        mem_resp_ready    // RREADY
);

    // ================== CORE ARRAYS ==================
    reg [TAG_BITS-1:0]  tag_array   [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg                 valid_array [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [511:0]         data_array  [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [2:0]           plru        [0:NUM_SETS-1];

    // ================== ADDRESS SPLIT ==================
    wire [INDEX_BITS-1:0] index    = req_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    wire [TAG_BITS-1:0]   tag      = req_addr[31 -: TAG_BITS];
    wire [3:0]            word_off = req_addr[5:2]; // 0..15 trong line

    // ================== HIT DETECT ==================
    wire [NUM_WAYS-1:0] way_hit;
    wire hit = |way_hit;
    assign way_hit[0] = valid_array[0][index] && (tag_array[0][index] == tag);
    assign way_hit[1] = valid_array[1][index] && (tag_array[1][index] == tag);
    assign way_hit[2] = valid_array[2][index] && (tag_array[2][index] == tag);
    assign way_hit[3] = valid_array[3][index] && (tag_array[3][index] == tag);
    
    wire [1:0]  hit_way = way_hit[0] ? 2'd0 :
                          way_hit[1] ? 2'd1 :
                          way_hit[2] ? 2'd2 : 2'd3;

    // ================== MISS CONTEXT ==================
    reg [31:0]           miss_addr;
    reg [INDEX_BITS-1:0] miss_index;
    reg [TAG_BITS-1:0]   miss_tag;
    reg [3:0]            miss_word_off;

    // burst tiến trình
    reg [1:0]  state, next_state;
    localparam IDLE=2'b00, CHECK_TAG=2'b01, FILL=2'b10;

    reg [3:0]  beat_cnt;
    reg [3:0]  cur_off;
    wire [31:0] line_base = {miss_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};

    // ================== CPU HANDSHAKE ==================
    assign req_ready = (state==IDLE) && (!resp_valid || resp_ready);

    // resp giữ theo resp_ready
    reg        resp_valid_q;
    reg [31:0] resp_data_q;
    assign resp_valid = resp_valid_q;
    assign resp_data  = resp_data_q;

    // ================== AR (READ ADDRESS) HOLD ==================
    reg        ar_valid_q;
    reg [31:0] ar_addr_q;
    assign mem_req_valid = ar_valid_q;
    assign mem_req_addr  = ar_addr_q;

    // luôn sẵn sàng nhận R (đơn giản)
    assign mem_resp_ready = 1'b1;

    // ================== FSM ==================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:       next_state = req_valid ? CHECK_TAG : IDLE;
            CHECK_TAG:  next_state = hit ? IDLE : FILL;
            // Kết thúc fill theo RLAST (chuẩn bus)
            FILL:       next_state = (mem_resp_valid && mem_resp_last) ? IDLE : FILL;
            default:    next_state = IDLE;
        endcase
    end

    // ================== MISS ISSUE & ARADDR ==================
    // Khi phát hiện miss ở CHECK_TAG → phát AR một lần, giữ ARVALID đến ARREADY
    wire issue_miss = (state == CHECK_TAG) && req_valid && (~hit) && (~ar_valid_q);

    // Tính địa chỉ phát lần đầu: critical-word-first (wrapper nên dùng BURST=WRAP)
    wire [31:0] critical_addr = {req_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}} // base line (align 64B)
                              + {26'b0, word_off, 2'b00};                       // offset word*4 bytes

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ar_valid_q <= 1'b0;
            ar_addr_q  <= 32'b0;
        end else begin
            if (issue_miss) begin
                ar_valid_q <= 1'b1;
                ar_addr_q  <= critical_addr;
            end 
            else if (ar_valid_q && mem_req_ready) begin
                ar_valid_q <= 1'b0;     // memory đã nhận (ARREADY=1) → hạ ARVALID
            end
        end
    end

    // ================== LATCH MISS CONTEXT ==================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            miss_addr      <= 32'b0;
            miss_index     <= {INDEX_BITS{1'b0}};
            miss_tag       <= {TAG_BITS{1'b0}};
            miss_word_off  <= 4'd0;
        end 
        else if ((state==CHECK_TAG) && req_valid && ~hit) begin
            miss_addr      <= req_addr;
            miss_index     <= index;
            miss_tag       <= tag;
            miss_word_off  <= word_off;
        end
    end

    // ================== BURST PROGRESS (cur_off/beat_cnt) ==================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            beat_cnt <= 4'd0;
            cur_off  <= 4'd0;
        end 
        else begin
            // Bắt đầu fill ngay khi vào FILL (cur_off = word miss, critical-first)
            if ((state==CHECK_TAG) && req_valid && (~hit)) begin
                beat_cnt <= 4'd0;
                cur_off  <= miss_word_off;
            end 
            else if ((state==FILL) && mem_resp_valid) begin
                beat_cnt <= beat_cnt + 4'd1;
                // wrap tự nhiên 4-bit
                cur_off  <= cur_off + 4'd1;
            end
        end
    end

    // ================== RESP PRODUCE & HOLD ==================
    // 1) Hit: phát ngay ở CHECK_TAG
    // 2) Miss: phát ngay beat có cur_off == miss_word_off
    wire produce_hit_resp  = (state==CHECK_TAG) && hit;
    wire produce_fill_resp = (state==FILL) && mem_resp_valid && (cur_off == miss_word_off);

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            resp_valid_q <= 1'b0;
            resp_data_q  <= 32'b0;
        end 
        else begin
            // Ưu tiên nạp dữ liệu mới khi tới
            if (produce_hit_resp) begin
                resp_valid_q <= 1'b1;
                case (1'b1)
                    way_hit[0]: resp_data_q <= data_array[0][index][(word_off*32)+:32];
                    way_hit[1]: resp_data_q <= data_array[1][index][(word_off*32)+:32];
                    way_hit[2]: resp_data_q <= data_array[2][index][(word_off*32)+:32];
                    way_hit[3]: resp_data_q <= data_array[3][index][(word_off*32)+:32];
                    default:    resp_data_q <= 32'b0;
                endcase
            end 
            else if (produce_fill_resp) begin
                resp_valid_q <= 1'b1;
                resp_data_q  <= mem_resp_data;
            end 
            else if (resp_valid_q && resp_ready) begin
                resp_valid_q <= 1'b0;
            end
        end
    end

    // ================== LRU ==================
    wire [1:0] lru_way;
    plru_lookup u_plru_lkp (.plru(plru[index]), .lru_way(lru_way));
    wire [1:0] victim_way = lru_way;

    wire [2:0] plru_new_hit, plru_new_fill;
    plru_update u_plru_upd_hit  (.plru_in(plru[index]),      .way_access(hit_way),  .plru_out(plru_new_hit));
    plru_update u_plru_upd_fill (.plru_in(plru[miss_index]), .way_access(victim_way), .plru_out(plru_new_fill));
    // (update ở cuối khi xong fill; lúc hit update ngay)

    // ================== WRITEBACK LINE ON FILL ==================
    integer si;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (si = 0; si < NUM_SETS; si = si + 1'b1) begin
                plru[si] <= 3'b000;
                valid_array[0][si] <= 1'b0; data_array[0][si] <= 512'b0; tag_array[0][si] <= {TAG_BITS{1'b0}};
                valid_array[1][si] <= 1'b0; data_array[1][si] <= 512'b0; tag_array[1][si] <= {TAG_BITS{1'b0}};
                valid_array[2][si] <= 1'b0; data_array[2][si] <= 512'b0; tag_array[2][si] <= {TAG_BITS{1'b0}};
                valid_array[3][si] <= 1'b0; data_array[3][si] <= 512'b0; tag_array[3][si] <= {TAG_BITS{1'b0}};
            end
        end 
        else begin
            // Update PLRU khi hit
            if ((state==CHECK_TAG) && hit)
                plru[index] <= plru_new_hit;

            // Ghi từng beat khi fill
            if ((state==FILL) && mem_resp_valid) begin
                // Ở đây ghi vào way victim (đã chọn trước)
                data_array[victim_way][miss_index][(cur_off*32) +: 32] <= mem_resp_data;

                // Kết thúc burst theo RLAST
                if (mem_resp_last) begin
                    tag_array [victim_way][miss_index]  <= miss_tag;
                    valid_array[victim_way][miss_index] <= 1'b1;
                    plru[miss_index]                    <= plru_new_fill;
                end
            end
        end
    end

endmodule
