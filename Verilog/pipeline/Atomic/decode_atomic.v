`timescale 1ns / 1ps

module decode_atomic #(
    parameter INSTR_WIDTH = 32,
    parameter ID_WIDTH    = 4,
    parameter SUPPORT_RV64 = 0
) (
    input  [INSTR_WIDTH-1:0] instruction,
    input  [ID_WIDTH-1:0]    core_id,
    
    output reg               is_atomic,
    output reg               is_lr,
    output reg               is_sc,
    output reg               is_amo,
    
    output reg [4:0]         rs1,
    output reg [4:0]         rs2,
    output reg [4:0]         rd,
    
    output reg [4:0]         funct5,
    output reg               aq,
    output reg               rl,
    output reg [5:0]         atop,
    output reg               is_rv64,
    
    output reg               is_valid_atomic,
    output reg [3:0]         error_code
);

    // Extract fields from RISC-V instruction word
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [4:0]  rd_field, rs1_field, rs2_field;
    wire [4:0]  funct5_field;
    wire        aq_bit, rl_bit;

    // Parse R-type atomic instruction format: funct5[31:27], aq[26], rl[25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]
    assign opcode       = instruction[6:0];
    assign funct3       = instruction[14:12];
    assign rd_field     = instruction[11:7];
    assign rs1_field    = instruction[19:15];
    assign rs2_field    = instruction[24:20];
    assign funct5_field = instruction[31:27];
    assign aq_bit       = instruction[26];  // Acquire bit: prevents later ops from executing before this
    assign rl_bit       = instruction[25];  // Release bit: prevents this op from executing until earlier ops complete

    always @(*) begin
        is_atomic       = 1'b0;
        is_lr           = 1'b0;
        is_sc           = 1'b0;
        is_amo          = 1'b0;
        is_valid_atomic = 1'b0;
        is_rv64         = 1'b0;
        error_code      = 4'h0;
        
        rs1 = rs1_field;
        rs2 = rs2_field;
        rd  = rd_field;
        funct5 = funct5_field;
        aq  = aq_bit;
        rl  = rl_bit;
        atop = 6'b000000;

        // RISC-V Atomic Extension - opcode 0x2F (0101111)
        if (opcode == 7'b0101111) begin
            is_atomic = 1'b1;

            // RV32A: 32-bit atomic operations (funct3 = 0x2)
            if (funct3 == 3'b010) begin
                is_valid_atomic = 1'b1;
                is_rv64 = 1'b0;

                case(funct5_field)
                    // LR.W (Load-Reserved): Load with reservation, acquires exclusive access to address
                    5'b00010: begin
                        is_lr = 1'b1;
                        if (rs2_field != 5'h0) begin
                            is_valid_atomic = 1'b0;
                            error_code = 4'h1;  // rs2 must be x0 for LR
                        end
                    end
                    
                    // SC.W (Store-Conditional): Store succeeds only if reservation still valid at same address
                    5'b00011: is_sc = 1'b1;
                    
                    // AMO operations: Atomic Read-Modify-Write
                    // Each AMO loads memory, applies operation, stores result
                    5'b00001: begin is_amo = 1'b1; atop = 6'b110000; end  // AMOSWAP.W: Exchange register and memory
                    5'b00000: begin is_amo = 1'b1; atop = 6'b100000; end  // AMOADD.W: Atomic add to memory
                    5'b00100: begin is_amo = 1'b1; atop = 6'b100010; end  // AMOXOR.W: Atomic bitwise XOR
                    5'b01010: begin is_amo = 1'b1; atop = 6'b100011; end  // AMOOR.W: Atomic bitwise OR
                    5'b01100: begin is_amo = 1'b1; atop = 6'b100001; end  // AMOAND.W: Atomic bitwise AND
                    5'b10000: begin is_amo = 1'b1; atop = 6'b100101; end  // AMOMIN.W: Atomic signed minimum
                    5'b10100: begin is_amo = 1'b1; atop = 6'b100100; end  // AMOMAX.W: Atomic signed maximum
                    5'b10001: begin is_amo = 1'b1; atop = 6'b100111; end  // AMOMINU.W: Atomic unsigned minimum
                    5'b10101: begin is_amo = 1'b1; atop = 6'b100110; end  // AMOMAXU.W: Atomic unsigned maximum
                    
                    default: begin
                        is_valid_atomic = 1'b0;
                        error_code = 4'h2;  // Unknown funct5
                    end
                endcase
            end
            // RV64A: 64-bit atomic operations (funct3 = 0x3, only if SUPPORT_RV64 enabled)
            else if (funct3 == 3'b011 && SUPPORT_RV64) begin
                is_valid_atomic = 1'b1;
                is_rv64 = 1'b1;

                case(funct5_field)
                    // LR.D (Load-Reserved 64-bit)
                    5'b00010: begin
                        is_lr = 1'b1;
                        if (rs2_field != 5'h0) begin
                            is_valid_atomic = 1'b0;
                            error_code = 4'h1;
                        end
                    end
                    // SC.D (Store-Conditional 64-bit)
                    5'b00011: is_sc = 1'b1;
                    // 64-bit AMO operations (same funct5 codes as 32-bit)
                    5'b00001: begin is_amo = 1'b1; atop = 6'b110000; end  // AMOSWAP.D
                    5'b00000: begin is_amo = 1'b1; atop = 6'b100000; end  // AMOADD.D
                    5'b00100: begin is_amo = 1'b1; atop = 6'b100010; end  // AMOXOR.D
                    5'b01010: begin is_amo = 1'b1; atop = 6'b100011; end  // AMOOR.D
                    5'b01100: begin is_amo = 1'b1; atop = 6'b100001; end  // AMOAND.D
                    5'b10000: begin is_amo = 1'b1; atop = 6'b100101; end  // AMOMIN.D
                    5'b10100: begin is_amo = 1'b1; atop = 6'b100100; end  // AMOMAX.D
                    5'b10001: begin is_amo = 1'b1; atop = 6'b100111; end  // AMOMINU.D
                    5'b10101: begin is_amo = 1'b1; atop = 6'b100110; end  // AMOMAXU.D
                    default: begin
                        is_valid_atomic = 1'b0;
                        error_code = 4'h2;
                    end
                endcase
            end
            // 64-bit requested but not supported
            else if (funct3 == 3'b011 && !SUPPORT_RV64) begin
                is_valid_atomic = 1'b0;
                error_code = 4'h4;  // 64-bit not supported
            end
            // Invalid funct3 value
            else begin
                is_valid_atomic = 1'b0;
                error_code = 4'h3;  // Invalid funct3
            end
        end else begin
            is_atomic = 1'b0;
            is_valid_atomic = 1'b0;
        end
    end

endmodule
