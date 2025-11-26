`timescale 1ns / 1ps

module decode_atomic #(
    parameter INSTR_WIDTH = 32,
    parameter ID_WIDTH    = 4
) (
    input  [INSTR_WIDTH-1:0] instruction,
    input  [ID_WIDTH-1:0]    core_id,
    
    // Decoded instruction type
    output reg               is_atomic,
    output reg               is_lr,
    output reg               is_sc,
    output reg               is_amo,
    
    // Register operands
    output reg [4:0]         rs1,
    output reg [4:0]         rs2,
    output reg [4:0]         rd,
    
    // Atomic operation details
    output reg [4:0]         funct5,
    output reg               aq,
    output reg               rl,
    
    // ATOP signal for AXI [5:1]=funct5, [0]=atomic_marker
    output reg [5:0]         atop,
    
    // Error checking
    output reg               is_valid_atomic,
    output reg [3:0]         error_code
);

    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [4:0]  rd_field, rs1_field, rs2_field;
    wire [4:0]  funct5_field;
    wire        aq_bit, rl_bit;

    // Parse instruction fields (R-type format for atomic)
    // [31:27]=funct5, [26]=aq, [25]=rl, [24:20]=rs2, [19:15]=rs1, [14:12]=funct3, [11:7]=rd, [6:0]=opcode
    assign opcode       = instruction[6:0];
    assign funct3       = instruction[14:12];
    assign rd_field     = instruction[11:7];
    assign rs1_field    = instruction[19:15];
    assign rs2_field    = instruction[24:20];
    assign funct5_field = instruction[31:27];
    assign aq_bit       = instruction[26];
    assign rl_bit       = instruction[25];

    // Combinational decoding logic
    always @(*) begin
        // Default values
        is_atomic = 1'b0;
        is_lr = 1'b0;
        is_sc = 1'b0;
        is_amo = 1'b0;
        is_valid_atomic = 1'b0;
        error_code = 4'h0;
        
        rs1 = rs1_field;
        rs2 = rs2_field;
        rd = rd_field;
        funct5 = funct5_field;
        aq = aq_bit;
        rl = rl_bit;
        atop = 6'b000000; // Default: No atomic operation
        
        // Check opcode = 0x2F (RV32A)
        if (opcode == 7'b0101111) begin
            is_atomic = 1'b1;
            
            // Check funct3 = 0x2 (32-bit)
            if (funct3 == 3'b010) begin
                is_valid_atomic = 1'b1;
                
                // Decode based on funct5
                case(funct5_field)
                    5'b00010: begin  // LR.W (0x02)
                        is_lr = 1'b1;
                        if (rs2_field != 5'h0) begin
                            is_valid_atomic = 1'b0;
                            error_code = 4'h1;
                        end
                    end
                    
                    5'b00011: is_sc = 1'b1;      // SC.W (0x03)
                    
                    // AXI5 AtomicLoad Encodings (10xxxx) and AtomicSwap (110000)
                    5'b00001: begin is_amo = 1'b1; atop = 6'b110000; end // AMOSWAP.W -> AtomicSwap
                    5'b00000: begin is_amo = 1'b1; atop = 6'b100000; end // AMOADD.W  -> AtomicLoad ADD
                    5'b00100: begin is_amo = 1'b1; atop = 6'b100010; end // AMOXOR.W  -> AtomicLoad EOR
                    5'b01010: begin is_amo = 1'b1; atop = 6'b100011; end // AMOOR.W   -> AtomicLoad SET
                    5'b01100: begin is_amo = 1'b1; atop = 6'b100001; end // AMOAND.W  -> AtomicLoad CLR (Requires Inversion)
                    5'b10000: begin is_amo = 1'b1; atop = 6'b100101; end // AMOMIN.W  -> AtomicLoad SMIN
                    5'b10100: begin is_amo = 1'b1; atop = 6'b100100; end // AMOMAX.W  -> AtomicLoad SMAX
                    
                    default: begin
                        is_valid_atomic = 1'b0;
                        error_code = 4'h2;
                    end
                endcase
            end else begin
                is_valid_atomic = 1'b0;
                error_code = 4'h3;
            end
        end else begin
            is_atomic = 1'b0;
            is_valid_atomic = 1'b0;
        end
    end

    // DEBUG


endmodule


module decode_atomic_controller #(
    parameter INSTR_WIDTH = 32,
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter ID_WIDTH    = 4
) (
    input  clk,
    input  rstn,
    
    // From Instruction Fetch
    input  [INSTR_WIDTH-1:0] instr,
    input  [ADDR_WIDTH-1:0]  pc,
    input  [ID_WIDTH-1:0]    core_id,
    input                    instr_valid,
    output                   instr_ready,
    
    // From Register File
    input  [DATA_WIDTH-1:0]  rs1_data,
    input  [DATA_WIDTH-1:0]  rs2_data,
    
    // To Atomic Unit
    output reg [ADDR_WIDTH-1:0] atomic_addr,
    output reg [DATA_WIDTH-1:0] atomic_operand,
    output reg [ID_WIDTH-1:0]   atomic_id,
    output reg [5:0]            atomic_atop,
    output reg [2:0]            atomic_user,
    output reg                  atomic_valid,
    input                       atomic_ready,
    
    // Status
    output reg                  decode_error,
    output reg [3:0]            error_code
);

    wire                is_atomic_instr;
    wire                is_lr_instr;
    wire                is_sc_instr;
    wire                is_amo_instr;
    wire [4:0]          rd_decoded;
    wire [4:0]          rs1_decoded;
    wire [4:0]          rs2_decoded;
    wire [4:0]          funct5_decoded;
    wire                aq_decoded;
    wire                rl_decoded;
    wire [5:0]          atop_decoded;
    wire                valid_atomic;
    wire [3:0]          error_decoded;

    decode_atomic decoder_inst (
        .instruction(instr),
        .core_id(core_id),
        .is_atomic(is_atomic_instr),
        .is_lr(is_lr_instr),
        .is_sc(is_sc_instr),
        .is_amo(is_amo_instr),
        .rs1(rs1_decoded),
        .rs2(rs2_decoded),
        .rd(rd_decoded),
        .funct5(funct5_decoded),
        .aq(aq_decoded),
        .rl(rl_decoded),
        .atop(atop_decoded),
        .is_valid_atomic(valid_atomic),
        .error_code(error_decoded)
    );

    always @(posedge clk) begin
        if (!rstn) begin
            atomic_valid <= 1'b0;
            atomic_addr <= 32'h0;
            atomic_operand <= 32'h0;
            atomic_id <= 4'h0;
            atomic_atop <= 6'h0;
            atomic_user <= 3'h0;
            decode_error <= 1'b0;
            error_code <= 4'h0;
        end else begin
            if (instr_valid && is_atomic_instr && valid_atomic) begin
                atomic_addr <= rs1_data;
                atomic_operand <= rs2_data;
                atomic_id <= core_id;
                atomic_atop <= atop_decoded;
                atomic_user[0] <= is_lr_instr;
                atomic_user[1] <= is_sc_instr;
                atomic_valid <= 1'b1;
                decode_error <= 1'b0;
                error_code <= 4'h0;
            end else if (instr_valid && is_atomic_instr && !valid_atomic) begin
                atomic_valid <= 1'b0;
                decode_error <= 1'b1;
                error_code <= error_decoded;
            end else if (atomic_ready) begin
                atomic_valid <= 1'b0;
            end
        end
    end

    assign instr_ready = atomic_ready || !is_atomic_instr;

endmodule