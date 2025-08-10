module plru_update (
    input  [2:0] plru_in,    // giá trị PLRU cũ
    input  [1:0] way_access, // way vừa được truy cập
    output reg [2:0] plru_out // giá trị PLRU mới
);
    always @(*) begin
        case (way_access)
            2'd0: begin
                plru_out[2] = 1'b1; // root: right subtree là LRU
                plru_out[1] = 1'b1; // left node: way1 là LRU
            end
            2'd1: begin
                plru_out[2] = 1'b1; // root: right subtree là LRU
                plru_out[1] = 1'b0; // left node: way0 là LRU
            end
            2'd2: begin
                plru_out[2] = 1'b0; // root: left subtree là LRU
                plru_out[0] = 1'b1; // right node: way3 là LRU
            end
            2'd3: begin
                plru_out[2] = 1'b0; // root: left subtree là LRU
                plru_out[0] = 1'b0; // right node: way2 là LRU
            end
            default: plru_out = plru_in; // mặc định giữ nguyên
        endcase
    end
endmodule
