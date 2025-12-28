module control_read #(
    parameter DATA_W = 32
)(
    input                       clk,
    input                       rst_n,
    
    // AR Channel
    input                       arvalid,
    output reg                  arready,
    input       [1:0]           arburst,
    input       [2:0]           arsize,
    input       [7:0]           arlen,
    input       [DATA_W-1:0]    araddr,
    
    // R Channel 
    input                       rready,
    output                      rlast,
    output reg                  rvalid,

    // Memory Interface
    output      [DATA_W-1:0]    r_addr,
    output reg                  read_en
);

    localparam IDLE = 1'd0;
    localparam READ = 1'd1;

    reg             state, next_state;
    reg [7:0]       read_count;     
    reg [DATA_W-1:0] reg_addr;

    // Registers to latch Control info
    reg [1:0]       reg_arburst;
    reg [2:0]       reg_arsize;
    reg [7:0]       reg_arlen;

    // ---------------------------------------- ARREADY LOGIC ----------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) arready <= 1'b0;
        else begin
            if (state == IDLE && !arvalid) begin
                arready <= 1'b1;
            end 
            else if (arvalid && arready) begin   
                arready <= 1'b0; 
            end 
            else if (state != IDLE) begin        
                arready <= 1'b0;
            end 
        end
    end

    // ---------------------------------------- DATA PATH ----------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            reg_addr    <= {DATA_W{1'b0}};
            read_count  <= 8'd0;
            reg_arburst <= 2'b00;
            reg_arsize  <= 3'b00;
            reg_arlen   <= 8'd0;
            rvalid      <= 1'b0;
        end 
        else begin
            state <= next_state;
            if (next_state == READ) begin 
                rvalid <= 1'b1;
            end
            else begin                    
                rvalid <= 1'b0;
            end 

            case(state)
                IDLE: begin
                    read_count <= 8'd0;
                    if (arvalid && arready) begin
                        reg_addr    <= araddr;
                        reg_arburst <= arburst;
                        reg_arsize  <= arsize;
                        reg_arlen   <= arlen;
                    end
                end

                READ: begin
                    if (rvalid && rready) begin
                        if (read_count < reg_arlen) begin
                             read_count <= read_count + 1'b1;

                             case (reg_arburst) 
                                2'b00: reg_addr <= reg_addr; // FIXED
                                2'b01: reg_addr <= reg_addr + (1 << reg_arsize); // INCR
                                2'b10: reg_addr <= reg_addr + (1 << reg_arsize); // WRAP
                                default: reg_addr <= reg_addr + (1 << reg_arsize);
                            endcase
                        end
                        else begin
                            read_count <= 8'd0;
                        end
                    end
                end
            endcase
        end
    end
    
    // ---------------------------------------- OUTPUT ----------------------------------------
    assign r_addr = reg_addr;
    assign rlast  = (read_count == reg_arlen) && rvalid; 

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
                if (rlast && rready) begin 
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