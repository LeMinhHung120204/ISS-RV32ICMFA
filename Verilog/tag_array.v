module tag_array(
    input         clk,
    input  [5:0]  addr,     // 64 dòng → 6-bit index
    input  [22:0] wdata,    // Dữ liệu ghi vào (tag + valid bit)
    output [22:0] rdata,    // Dữ liệu đọc ra
    input         en,       // Enable truy cập (đọc hoặc ghi)
    input         wmode,    // 1: ghi, 0: đọc
    input         wmask     // Mask ghi (chỉ ghi khi = 1)
);

    // Bộ nhớ tag
    reg [22:0] ram [0:63];

    // Pipeline 1 chu kỳ delay cho đọc
    reg        read_en_pipe;
    reg [5:0]  read_addr_pipe;

    // Đọc
    assign rdata = read_en_pipe ? ram[read_addr_pipe] : 25'b0;

    always @(posedge clk) begin
        // Nếu ghi
        if (en && wmode && wmask) begin
            ram[addr] <= wdata;
        end

        // Ghi địa chỉ đọc để lấy dữ liệu ở chu kỳ sau
        if (en && !wmode) begin
            read_en_pipe   <= 1'b1;
            read_addr_pipe <= addr;
        end else begin
            read_en_pipe <= 1'b0;
        end
    end

endmodule
