`timescale 1ns/1ps

module atomic_unit_ace #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32
)(
    input clk, rst_n,
    
    // Control signals
    input valid_input,          // Start atomic operation
    output reg ready,           // Unit ready for new operation
    output wire valid_output,   // Atomic operation done
    
    // Data inputs
    input [4:0] funct5,         // Atomic operation type (from atomic_decoder)
    input aq, rl,               // Acquire/Release flags
    input [WIDTH_ADDR-1:0] addr,// Target address
    input [WIDTH_DATA-1:0] rs1_data, rs2_data,  // Operands
    
    // Result output
    output reg [WIDTH_DATA-1:0] rd_value,
    
    // ACE/AXI Bus Interface (simplified)
    output wire m_ARVALID, m_AWVALID, m_WVALID, m_RVALID, m_BVALID,
    input wire m_ARREADY, m_AWREADY, m_WREADY,
    output wire [WIDTH_ADDR-1:0] m_ARADDR, m_AWADDR,
    output wire [WIDTH_DATA-1:0] m_WDATA,
    input wire [WIDTH_DATA-1:0] m_RDATA,
    output wire m_RLAST, m_WLAST
);
    
    // ===== STATE MACHINE =====
    localparam IDLE = 3'b000;
    localparam READ = 3'b001;
    localparam ALU  = 3'b010;
    localparam WRITE = 3'b011;
    localparam DONE = 3'b100;
    
    reg [2:0] state, next_state;
    reg [WIDTH_DATA-1:0] read_data, alu_result;
    reg [4:0] current_funct5;
    reg current_aq, current_rl;
    reg [WIDTH_ADDR-1:0] current_addr;
    reg [WIDTH_DATA-1:0] current_rs2;
    
    // ===== RESERVATION SET (per-hart) =====
    reg reservation_valid;
    reg [WIDTH_ADDR-1:0] reservation_addr;
    
    // ===== OUTPUT ASSIGNMENTS =====
    assign valid_output = (state == DONE);
    
    // Simple bus control (tie-off for now, can be expanded for ACE)
    assign m_ARVALID = (state == READ);
    assign m_ARADDR = current_addr;
    assign m_AWVALID = (state == WRITE);
    assign m_AWADDR = current_addr;
    assign m_WVALID = (state == WRITE);
    assign m_WDATA = alu_result;
    assign m_RLAST = 1'b1;
    assign m_WLAST = 1'b1;
    
    // ===== STATE MACHINE LOGIC =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            rd_value <= 0;
            reservation_valid <= 1'b0;
        end else begin
            state <= next_state;
            
            // Update ready signal
            ready <= (next_state == IDLE) ? 1'b1 : 1'b0;
            
            case(state)
                IDLE: begin
                    if (valid_input) begin
                        current_funct5 <= funct5;
                        current_aq <= aq;
                        current_rl <= rl;
                        current_addr <= addr;
                        current_rs2 <= rs2_data;
                    end
                end
                
                READ: begin
                    if (m_ARREADY) begin
                        read_data <= m_RDATA;  // Capture read data
                    end
                end
                
                ALU: begin
                    // ALU computation happens here (combinational)
                    alu_result <= perform_amo(read_data, current_rs2, current_funct5);
                end
                
                WRITE: begin
                    if (m_AWREADY && m_WREADY) begin
                        // Write done, update reservation for SC
                        if (current_funct5 == 5'b00011) begin // SC.W
                            reservation_valid <= 1'b0;
                        end else if (current_funct5 == 5'b00010) begin // LR.W
                            reservation_valid <= 1'b1;
                            reservation_addr <= current_addr;
                        end
                    end
                end
                
                DONE: begin
                    // Result available in rd_value
                    rd_value <= (current_funct5 == 5'b00011) ? 
                                {31'b0, ~reservation_valid} :  // SC: return 0 if success, 1 if fail
                                read_data;  // AMO/LR: return old value
                end
            endcase
            
            // ===== RESERVATION INVALIDATION =====
            // Invalidate reservation on exception or context-switch
            // (Placeholder: add more conditions as needed)
            if (!rst_n) begin
                reservation_valid <= 1'b0;
            end
        end
    end
    
    // ===== NEXT STATE LOGIC =====
    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if (valid_input) begin
                    next_state = READ;
                end
            end
            READ: begin
                if (m_ARREADY && m_RVALID) begin
                    next_state = ALU;
                end
            end
            ALU: begin
                next_state = WRITE;
            end
            WRITE: begin
                if (m_AWREADY && m_WREADY && m_BVALID) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // ===== AMO COMPUTATION FUNCTION =====
    function [WIDTH_DATA-1:0] perform_amo(
        input [WIDTH_DATA-1:0] mem_data,
        input [WIDTH_DATA-1:0] rs2_data,
        input [4:0] funct5
    );
        case(funct5)
            5'b00010: perform_amo = mem_data;           // LR.W: load-reserved
            5'b00011: perform_amo = mem_data;           // SC.W: store-conditional
            5'b00001: perform_amo = rs2_data;           // AMOSWAP.W
            5'b00000: perform_amo = mem_data + rs2_data; // AMOADD.W
            5'b00100: perform_amo = mem_data ^ rs2_data; // AMOXOR.W
            5'b01100: perform_amo = mem_data & rs2_data; // AMOAND.W
            5'b01000: perform_amo = mem_data | rs2_data; // AMOOR.W
            5'b10000: perform_amo = $signed(mem_data) < $signed(rs2_data) ? rs2_data : mem_data; // AMOMIN.W
            5'b10100: perform_amo = $signed(mem_data) > $signed(rs2_data) ? rs2_data : mem_data; // AMOMAX.W
            5'b11000: perform_amo = mem_data < rs2_data ? rs2_data : mem_data; // AMOMINU.W
            5'b11100: perform_amo = mem_data > rs2_data ? rs2_data : mem_data; // AMOMAXU.W
            default: perform_amo = 32'b0;
        endcase
    endfunction
    
endmodule
