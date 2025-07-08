module ICache (
    input         clk, reset,
    input         req_valid, // yêu cầu từ CPU
    input  [31:0] req_addr,  // địa chỉ yêu cầu từ CPU
    output        req_ready, // sẵn sàng nhận yêu cầu từ CPU

    // interface to memory
    output        mem_req_valid,    // yêu cầu từ cache đến memory
    output [31:0] mem_req_addr,     // địa chỉ yêu cầu từ cache đến memory
    input         mem_resp_valid,   // phản hồi từ memory
    input  [31:0] data_in,          // dữ liệu trả về từ memory

    output        resp_valid,       // phản hồi từ cache đến CPU
    output [31:0] resp_data,        // dữ liệu trả về từ cache đến CPU
    output        hit               // hit signal indicating cache hit
);

    localparam NUM_SETS = 64;
    localparam NUM_WAYS = 4;
    localparam OFFSET_BITS = 2;  // 4B block
    localparam INDEX_BITS  = 6;  // 64 sets
    localparam TAG_BITS    = 24; // 32 - 6 - 2

    typedef enum logic [1:0] {
        IDLE,
        MISS,
        WAIT,
        FILL
    } state_t;

    state_t state, next_state;

    wire [TAG_BITS-1:0]   tag     = addr[31:8];
    wire [INDEX_BITS-1:0] index   = addr[7:2];
    wire [OFFSET_BITS-1:0] offset = addr[1:0];

    // Tag, Valid and Data arrays
    reg [TAG_BITS-1:0] tag_array   [0:NUM_WAYS-1][0:NUM_SETS-1]; // mảng 2 chiều chứa TAG cho từng block.
    reg                valid_array [0:NUM_WAYS-1][0:NUM_SETS-1]; // mảng 2 chiều chứa bit valid cho từng block.
    reg [31:0]         data_array  [0:NUM_WAYS-1][0:NUM_SETS-1]; // mảng 2 chiều chứa dữ liệu cho từng block.


    // LRU: 2-bit priority value per way per set (0 = most recent, 3 = least)
    reg [1:0] lru_priority [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [1:0]          victim_way;

    reg [NUM_WAYS-1:0] way_hit;
    reg [31:0]         data_sel;
    

    integer i;
    always @(*) begin
        way_hit = 0;
        data_sel = 32'b0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (valid_array[i][index] && tag_array[i][index] == tag) begin
                way_hit[i] = 1;
                data_sel = data_array[i][index];
            end
        end
    end

    // FSM - state transitions
    always @(*) begin
        case (state)
            IDLE:   next_state = (req_valid && !hit) ? MISS : IDLE;
            MISS:   next_state = WAIT;
            WAIT:   next_state = mem_resp_valid ? FILL : WAIT;
            FILL:   next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // FSM - state updates
    always @(posedge clk or negedge reset) begin
        if (!reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Victim way logic: find way with LRU priority == 2'b11 (least recently used)
    always @(*) begin
        victim_way = 0;
        for (i = 0; i < NUM_WAYS; i = i + 1) begin
            if (lru_priority[index][i] == 2'b11)
                victim_way = i;
        end
    end

    // Update LRU priorities
    task update_lru;
        input [1:0] used_way;
        integer j;
        begin
            for (j = 0; j < NUM_WAYS; j = j + 1) begin
                if (j != used_way && lru_priority[index][j] < lru_priority[index][used_way])
                    lru_priority[index][j] = lru_priority[index][j] + 1;
            end
            lru_priority[index][used_way] = 2'b00; // most recently used
        end
    endtask

    // Cache refill logic using victim way from LRU
    always @(posedge clk) begin
        if (state == FILL) begin
            tag_array[victim_way][index]   <= tag;
            data_array[victim_way][index]  <= data_in;
            valid_array[victim_way][index] <= 1'b1;
            update_lru(victim_way);
        end else if (hit && req_valid) begin
            for (i = 0; i < NUM_WAYS; i = i + 1)
                if (way_hit[i])
                    update_lru(i);
        end
    end

    // Outputs
    assign hit = |way_hit; // hit nếu có ít nhất một way hợp lệ và tag khớp
    assign req_ready = (state == IDLE); // sẵn sàng nhận yêu cầu nếu không có yêu cầu hoặc đã hit
    assign mem_req_valid = (state == MISS); // yêu cầu đến memory khi ở trạng thái MISS
    assign mem_req_addr  = req_addr; // địa chỉ yêu cầu từ CPU
    assign resp_valid = hit; // phản hồi hợp lệ nếu có hit
    assign resp_data = data_sel; // dữ liệu trả về từ cache đến CPU

endmodule