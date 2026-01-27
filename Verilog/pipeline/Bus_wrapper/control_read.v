`timescale 1ns/1ps
module control_read #(
    parameter DATA_W = 32
)(
    input                               clk,
    input                               rst_n,
    
    // AR Channel
    input                               arvalid,
    output reg                          arready,
    input       [1:0]                   arburst,
    input       [2:0]                   arsize,
    input       [7:0]                   arlen,
    input       [DATA_W-1:0]            araddr,
    
    // R Channel 
    input                               fifo_r_push_able,
    input                               fifo_r_pop_able,
    input                               rvalid_from_mem,
    output reg                          last_data_from_mem,

    // Memory Interface
    input                               fifo_ar_full,
    output      [DATA_W-1:0]            r_addr,
    output reg                          read_en
);

    localparam IDLE = 1'd0;
    localparam READ = 1'd1;

    reg                 state, next_state;
    reg [7:0]           count_addr, read_count;     
    reg [DATA_W-1:0]    reg_addr;

    // Registers to latch Control info
    reg [1:0]       reg_arburst;
    reg [2:0]       reg_arsize;
    reg [7:0]       reg_arlen;

    // ---------------------------------------- ARREADY LOGIC ----------------------------------------
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) arready <= 1'b0;
    //     else begin
    //         if (state == IDLE && !arvalid) begin
    //             arready <= 1'b1;
    //         end 
    //         else if (arvalid && arready) begin   
    //             arready <= 1'b0; 
    //         end 
    //         else if (state != IDLE) begin        
    //             arready <= 1'b0;
    //         end 
    //     end
    // end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            arready <= 1'b0;
        else begin
            if (state == IDLE && ~fifo_ar_full) 
                arready <= 1'b1;
            else 
                arready <= 1'b0;
        end
    end

    // ---------------------------------------- tinh address de doc data tu mem ----------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            reg_addr    <= {DATA_W{1'b0}};
            count_addr  <= 8'd0;
            reg_arburst <= 2'b00;
            reg_arsize  <= 3'b00;
            reg_arlen   <= 8'd0;
        end 
        else begin
            state <= next_state;
            case(state)
                IDLE: begin
                    count_addr <= 8'd0;
                    if (arvalid && arready) begin
                        reg_addr    <= araddr >> 2; // dang de address / 4 de doc file hex
                        reg_arburst <= arburst;
                        reg_arsize  <= arsize;
                        reg_arlen   <= arlen;
                    end
                end

                READ: begin
                    if (fifo_r_push_able) begin
                        if (count_addr < reg_arlen) begin
                             count_addr <= count_addr + 1'b1;
                            case (reg_arburst) 
                                2'b00: reg_addr <= reg_addr; // FIXED
                                // For INCR/WRAP increment by one word (reg_addr stores word-index)
                                2'b01: reg_addr <= reg_addr + 1'b1; // INCR
                                2'b10: reg_addr <= reg_addr + 1'b1; // WRAP
                                default: reg_addr <= reg_addr + 1'b1;
                            endcase
                        end
                        else begin
                            count_addr <= 8'd0;
                        end
                    end
                end
            endcase
        end
    end
    
    // ---------------------------------------- OUTPUT ----------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_count <= 8'd0;
            last_data_from_mem <= 1'b0;
        end 
        else begin
            if (state == READ)
                last_data_from_mem <= (count_addr == reg_arlen);

            if (fifo_r_pop_able) begin
                if (read_count < reg_arlen) begin
                    read_count <= read_count + 1'b1;
                end
                else begin
                    read_count <= 8'd0;
                end
            end
        end
    end

    assign r_addr = reg_addr;


    // ---------------------------------------- FSM ----------------------------------------
    always @(*) begin
        case (state)
            IDLE: begin
                read_en = 1'b0;
                if (arvalid && arready) begin 
                    next_state = READ;
                end
                else begin                    
                    next_state = IDLE;
                end 
            end
            
            READ: begin
                read_en = 1'b1;  
                if ((count_addr == reg_arlen) && fifo_r_push_able) begin 
                    next_state = IDLE; 
                end 
                else begin                 
                    next_state = READ;
                end 
            end
            
            default: begin
                read_en    = 1'b0;
                next_state = IDLE;
            end 
        endcase
    end
endmodule