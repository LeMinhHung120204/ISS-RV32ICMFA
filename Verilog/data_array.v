module data_array(
    input         clk,      // Clock
    input  [9:0]  addr,     // 10-bit địa chỉ: 1024 dòng
    input  [31:0] wdata,    // Dữ liệu ghi vào
    output [31:0] rdata,    // Dữ liệu đọc ra
    input         en,       // Enable truy cập
    input         wmode,    // 1 = write, 0 = read
    input         wmask     // Ghi hay không
);

    // RAM 32-bit × 1024 dòng
    reg [31:0] ram [0:1023];

    // Pipeline cho read
    reg        read_en_pipe;
    reg [9:0]  read_addr_pipe;

    // Đọc sau 1 chu kỳ
    assign rdata = read_en_pipe ? ram[read_addr_pipe] : 32'b0;

    always @(posedge clk) begin
        // Ghi
        if (en && wmode && wmask) begin
            ram[addr] <= wdata;
        end

        // Ghi nhớ địa chỉ đọc để delay 1 chu kỳ
        if (en && !wmode) begin
            read_en_pipe   <= 1'b1;
            read_addr_pipe <= addr;
        end else begin
            read_en_pipe <= 1'b0;
        end
    end

endmodule