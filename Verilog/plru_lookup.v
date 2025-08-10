module plru_lookup (
    input  [2:0] plru,      // plru[2]=root, plru[1]=left, plru[0]=right
    output reg [1:0] lru_way
);
    always @(*) begin
        if (plru[2] == 1'b0) begin
            // left subtree LRU -> chọn giữa way0/1 theo plru[1]
            lru_way = (plru[1] == 1'b0) ? 2'b00 : 2'b01;
        end 
        else begin
            // right subtree LRU -> chọn giữa way2/3 theo plru[0]
            lru_way = (plru[0] == 1'b0) ? 2'b10 : 2'b11;
        end
    end
endmodule
