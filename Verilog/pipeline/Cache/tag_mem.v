module tag_mem #(
    parameter INDEX_WIDTH       = 10,
    parameter TAG_WIDTH         = 18,
    parameter NUM_CACHE_LINES   = 1024  // 2^(INDEX_WIDTH) = 1024 lines
)(
    input   clk, rst_n, we,
    input   [INDEX_WIDTH-1:0]   index,
    input   [TAG_WIDTH+1:0]     tag_write, // extra bits: {valid, dirty, tag}
    output  [TAG_WIDTH+1:0]     tag_read
);
    reg [TAG_WIDTH+1:0] tag_mem [0:NUM_CACHE_LINES-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            for (i = 0; i < NUM_CACHE_LINES; i = i + 1) begin
                tag_mem[i] <= {TAG_WIDTH+2{1'b0}};
            end
        end 
        else begin
            if (we) begin
                tag_mem[index] <= tag_write;
            end 
        end
    end

    assign tag_read = tag_mem[index];
endmodule