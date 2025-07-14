module ControlUnit(
    input      [6:0] OP,
    input      [6:0] funct7,
    input      [2:0] funct3 
    output reg [3:0] ALUOp,     // Mã điều khiển ALU
    output reg       RegWrite,   // Tín hiệu ghi vào thanh ghi
    output reg       MemRead,    // Tín hiệu đọc bộ nhớ
    output reg       MemWrite,   // Tín hiệu ghi bộ nhớ
    output reg       Branch,     // Tín hiệu nhánh
    output reg       Jump        // Tín hiệu nhảy
);
    
    always @(*) begin
        // Giả sử instruction được mã hoá theo định dạng RISC-V hoặc tương tự
        case (instruction[6:0]) // Lấy opcode từ lệnh
            7'b0110011: begin // R-type instructions
                ALUOp = instruction[14:12]; // ALUOp từ funct3
                RegWrite = 1'b1; // Ghi vào thanh ghi
                MemRead = 1'b0;  // Không đọc bộ nhớ
                MemWrite = 1'b0; // Không ghi bộ nhớ
                Branch = 1'b0;   // Không phải nhánh
                Jump = 1'b0;     // Không phải nhảy
            end
            
            7'b0000011: begin // I-type load instructions
                ALUOp = 4'b0010; // ALUOp cho phép load (cộng với offset)
                RegWrite = 1'b1; 
                MemRead = 1'b1;  
                MemWrite = 1'b0; 
                Branch = 1'b0;   
                Jump = 1'b0;     
            end
            
            7'b0100011: begin // S-type store instructions
                ALUOp = 4'b0010; 
                RegWrite = 1'b0; 
                MemRead = 1'b0;  
                MemWrite = 1'b1; 
                Branch = 1'b0;   
                Jump = 1'b0;     
            end
            
        endcase
    end
endmodule