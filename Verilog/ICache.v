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
    localparam OFFSET_BITS = 16;  // 64B(sua)
    localparam INDEX_BITS  = 6;  // 64 sets
    localparam TAG_BITS    = 32 - 16 - 6;

    localparam IDLE = 2'b00, MISS = 2'b01, FILL = 2'b10;
    reg [1:0] state, next_state;

    // Tag, Valid, and Data arrays
    reg [TAG_BITS-1:0]  tag_array   [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg                 valid_array [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [31:0]          data_array  [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [31:0]          resp_data_reg;

    // LRU: 2-bit priority value per way per set (0 = most recent, 3 = least)
    reg [1:0] lru [0:NUM_WAYS-1][0:NUM_SETS-1];
    reg [1:0] least_recent_used;

    wire [0:NUM_WAYS-1]     way_hit;
    wire [INDEX_BITS-1:0]   index;
    wire [TAG_BITS-1:0]     tag;

    // FSM state update
    always @(posedge clk or negedge reset) begin // rst_n (dat ten lai)
        if (~reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = (req_valid & ~hit) ? MISS : IDLE;
            MISS: next_state = mem_req_valid ? FILL : MISS;
            FILL: next_state = IDLE;
        endcase
    end

    assign tag      = req_addr[31:8]; // su dung parameter
    assign index    = req_addr[7:2]; // su dung parameter

    assign way_hit[0] = (tag_array[0][index] == tag) & valid_array[0][index];
    assign way_hit[1] = (tag_array[1][index] == tag) & valid_array[1][index];
    assign way_hit[2] = (tag_array[2][index] == tag) & valid_array[2][index];
    assign way_hit[3] = (tag_array[3][index] == tag) & valid_array[3][index];

    // chooose way to fill
    // psudo LRU algorithm tim hieu
    reg [1:0] least_way = 2'b00;
    always @(*) begin
        least_recent_used = 2'b00;
        if (lru[1][index] > least_recent_used) begin 
            least_recent_used = lru[1][index];
            least_way = 2'b01;
        end
        else if (lru[2][index] > least_recent_used) begin 
            least_recent_used = lru[2][index];
            least_way = 2'b10;
        end
        else if (lru[3][index] > least_recent_used) begin 
            least_recent_used = lru[3][index];
            least_way = 2'b11;
        end
    end 

    always @(posedge clk) begin
        if (state == FILL) begin
            tag_array[least_way][index] <= tag;
            data_array[least_way][index] <= data_in;    
            valid_array[least_way][index] <= 1'b1;
            // update LRU for other ways
            integer i;
            for (i = 0; i < NUM_WAYS; i = i + 1) begin
                if (i != least_way) begin
                    if (lru[i][index] <= lru[least_way][index]) begin
                        lru[i][index] <= lru[i][index] + 1'b1; // increment LRU value
                    end
                end
            end
            lru[least_way][index] <= 2'b00; // reset LRU for this way
        end
        else if (hit && req_valid) begin
            // Update LRU on hit
            integer i;
            for (i = 0; i < NUM_WAYS; i = i + 1) begin
                if (way_hit[i]) begin
                    lru[i][index] <= 2'b00; // reset LRU for this way
                end else begin
                    if (lru[i][index] < 2'd3) begin
                        lru[i][index] <= lru[i][index] + 1'b1; // increment LRU value
                    end
                end
            end
        end
    end 
    always @(*) begin
        case(way_hit)
            4'b0001: resp_data_reg = data_array[0][index];
            4'b0010: resp_data_reg = data_array[1][index];
            4'b0100: resp_data_reg = data_array[2][index];
            4'b1000: resp_data_reg = data_array[3][index];
            default: resp_data_reg = 32'b0;
        endcase
    end 

    // output 
    assign resp_data        = resp_data_reg;
    assign hit              = | way_hit;
    assign req_ready        = (state == IDLE) ? 1'b1 : 1'b0; // sẵn sàng nhận yêu cầu từ CPU
    assign mem_req_valid    = (state == MISS) ? 1'b1 : 1'b0; // yêu cầu đến memory khi ở trạng thái MISS
    assign mem_req_addr     = req_addr; // địa chỉ yêu cầu từ CPU
    assign resp_valid       = (((state == IDLE) & hit) | ((state == FILL) & mem_resp_valid)) ? 1'b1 : 1'b0; // phản hồi từ cache đến CPU

    

endmodule