`timescale 1ns / 1ps
module single_core #(
    parameter CORE_ID   = 1'b0,
    parameter ID_W      = 2,
    parameter ADDR_W    = 32,
    parameter DATA_W    = 32
)(
    input   ACLK,
    input   ARESETn,

    // Request Out
    output                  o_mem_req_valid,
    input                   i_mem_req_ready,
    output  [1:0]           o_mem_req_cmd,
    output  [ADDR_W-1:0]    o_mem_req_addr,

    // Write Data Out
    output  [DATA_W-1:0]    o_mem_wdata,
    output                  o_mem_wdata_valid,
    output                  o_mem_wdata_last,
    input                   i_mem_wdata_ready,

    // Read Data In
    input                   i_mem_rdata_valid,
    input                   i_mem_rdata_last,
    input   [DATA_W-1:0]    i_mem_rdata,
    output                  o_mem_rdata_ready,

    // Snoop In
    input                   i_snoop_valid,
    input   [ADDR_W-1:0]    i_snoop_addr,
    input   [1:0]           i_snoop_type,
    
    output                  o_snoop_hit,
    output                  o_snoop_dirty,
    output  [DATA_W-1:0]    o_snoop_data
);
   // CPU <-> L1
    wire [DATA_W-1:0]   data_rdata, data_wdata;
    wire [ADDR_W-1:0]   data_addr;
    wire [1:0]          data_size;
    wire                data_req, data_wr, dcache_stall;

    wire [DATA_W-1:0]   imem_instr;
    wire [ADDR_W-1:0]   icache_addr;
    wire                icache_req, icache_flush, icache_stall;

    // L1 <-> Arbiter <-> L2 Wires
    // I-Cache to Arbiter
    wire                l1i_req_valid;
    wire                l1i_req_ready;
    wire [ADDR_W-1:0]   l1i_req_addr;
    wire                l1i_rdata_valid;
    wire                l1i_rdata_last; // Refill done
    
    // D-Cache to Arbiter
    wire                l1d_req_valid;
    wire                l1d_req_ready;
    wire [1:0]          l1d_req_cmd;
    wire [ADDR_W-1:0]   l1d_req_addr;
    
    wire                l1d_wdata_valid;
    wire                l1d_wdata_ready;
    wire                l1d_wdata_last;
    wire [DATA_W-1:0]   l1d_wdata;
    
    wire                l1d_rdata_valid;
    wire                l1d_rdata_last;

    // Arbiter to L2 (Merged Interface)
    wire                l2_req_valid;
    wire                l2_req_ready;
    wire [1:0]          l2_req_cmd;
    wire [ADDR_W-1:0]   l2_req_addr;
    
    wire [DATA_W-1:0]   l2_wdata;       // Data ghi xuong L2 (tu D-cache)
    wire                l2_wdata_valid;
    wire                l2_wdata_ready;
    wire                l2_wdata_last;

    wire [DATA_W-1:0]   l2_rdata;       // Data doc tu L2 (-> L1)
    wire                l2_rdata_valid;
    wire                l2_rdata_last;
    wire                l2_rdata_ready;

    // Internal Snoop (L2 -> L1 D-Cache)
    wire                int_snoop_valid;
    wire [ADDR_W-1:0]   int_snoop_addr;
    wire [1:0]          int_snoop_type;
    wire                int_snoop_hit;
    wire                int_snoop_dirty;
    wire [DATA_W-1:0]   int_snoop_data;

    // ---------------------------------------- CPU CORE ----------------------------------------
    RV32IMF #(
        .WIDTH_ADDR (ADDR_W),
        .WIDTH_DATA (DATA_W)
    ) u_RV32IMF (
        .clk            (ACLK),
        .rst_n          (ARESETn),

        // Dcache Interface
        .data_rdata     (data_rdata),
        .data_req       (data_req),
        .data_wr        (data_wr),
        .data_size      (data_size),
        .data_addr      (data_addr),
        .data_wdata     (data_wdata),
        .dcache_stall   (dcache_stall),
        
        // Icache Interface
        .imem_instr     (imem_instr),
        .icache_req     (icache_req),
        .icache_flush   (icache_flush),
        .icache_addr    (icache_addr),
        .icache_stall   (icache_stall)
    );


    // ---------------------------------------- L1 CACHE ----------------------------------------
    icache #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) u_icache_L1 (
        .clk    (ACLK),
        .rst_n  (ARESETn),

        // cache <-> CPU
        .cpu_req        (icache_req),
        .cpu_addr       (icache_addr),
        .icache_flush   (icache_flush),
        .dcache_stall   (dcache_stall),
        .pipeline_stall (icache_stall),
        .data_rdata     (imem_instr),

        // Connect to Arbiter
        .i_l2_req_ready     (l1i_req_ready),
        .o_l2_req_valid     (l1i_req_valid),
        .o_l2_req_addr      (l1i_req_addr),

        // I-Cache chi nhan Data (Read Only)
        .i_l2_rdata_valid   (l1i_rdata_valid),
        .i_l2_rdata_last    (l1i_rdata_last),
        .i_l2_rdata         (l2_rdata),
        .o_l2_rdata_ready   ()
    );


    dcache #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) u_dcache_L1 (
        .clk    (ACLK),
        .rst_n  (ARESETn),

        // cache <-> CPU
        .cpu_req        (data_req),
        .cpu_we         (data_wr),
        .cpu_addr       (data_addr),
        .cpu_din        (data_wdata),
        .cpu_size       (data_size),
        .data_rdata     (data_rdata),
        .pipeline_stall (dcache_stall),

        // Connect to Arbiter
        // Request
        .i_l2_req_ready     (l1d_req_ready),
        .o_l2_req_valid     (l1d_req_valid),
        .o_l2_req_cmd       (l1d_req_cmd),
        .o_l2_req_addr      (l1d_req_addr),

        // Write Data (WB)
        .i_l2_wdata_ready   (l1d_wdata_ready),
        .o_l2_wdata         (l1d_wdata),
        .o_l2_wdata_valid   (l1d_wdata_valid),
        .o_l2_wdata_last    (l1d_wdata_last),
        
        // Read Data (Refill)
        .i_l2_rdata_valid   (l1d_rdata_valid),
        .i_l2_rdata_last    (l1d_rdata_last),
        .i_l2_rdata         (l2_rdata),
        .o_l2_rdata_ready   (),

        // Internal Snoop Port
        .i_snoop_valid      (int_snoop_valid),
        .i_snoop_addr       (int_snoop_addr),
        .i_snoop_type       (int_snoop_type),

        .o_snoop_hit        (int_snoop_hit),
        .o_snoop_dirty      (int_snoop_dirty),        
        .o_snoop_data       (int_snoop_data)
    );

    // ---------------------------------------- L1 ARBITER ----------------------------------------
    arbiter #( .ADDR_W(ADDR_W) ) u_l2_arbiter (
        .clk            (ACLK), 
        .rst_n          (ARESETn),

        // Client 0: I-Cache
        .i_c0_req_valid (l1i_req_valid),
        .i_c0_req_addr  (l1i_req_addr),
        .o_c0_req_ready (l1i_req_ready),

        // Client 1: D-Cache
        .i_c1_req_valid (l1d_req_valid),
        .i_c1_req_cmd   (l1d_req_cmd),
        .i_c1_req_addr  (l1d_req_addr),
        .o_c1_req_ready (l1d_req_ready),

        // To L2 Cache
        .i_l2_ready     (l2_req_ready),
        .o_l2_valid     (l2_req_valid),
        .o_l2_cmd       (l2_req_cmd),
        .o_l2_addr      (l2_req_addr)
    );

    // --- (Write Data) ---
    // D-Cache only
    assign l2_wdata         = l1d_wdata;
    assign l2_wdata_valid   = l1d_wdata_valid;
    assign l2_wdata_last    = l1d_wdata_last;
    assign l1d_wdata_ready  = l2_wdata_ready; 

    // --- Response (Read Data) ---
    assign l1d_rdata_valid  = l2_rdata_valid;
    assign l1d_rdata_last   = l2_rdata_last;

    assign l1i_rdata_valid  = l2_rdata_valid;
    assign l1i_rdata_last   = l2_rdata_last;
    // ---------------------------------------- L2 CACHE ----------------------------------------

    // dcache #( 
    //     .ADDR_W(ADDR_W), 
    //     .DATA_W(DATA_W) 
    //     // .SIZE_BYTES(256*1024) 
    // ) u_l2_cache (
    //     .clk    (ACLK), 
    //     .rst_n  (ARESETn),

    //     // --- Upstream Interface (-> Arbiter) ---
    //     .i_req_valid    (l2_req_valid),
    //     .o_req_ready    (l2_req_ready),
    //     .i_req_cmd      (l2_req_cmd),
    //     .i_req_addr     (l2_req_addr),
        
    //     .i_wdata        (l2_wdata),
    //     .i_wdata_valid  (l2_wdata_valid),
    //     .i_wdata_last   (l2_wdata_last),
    //     .o_wdata_ready  (l2_wdata_ready),

    //     .o_rdata        (l2_rdata),
    //     .o_rdata_valid  (l2_rdata_valid),
    //     .o_rdata_last   (l2_rdata_last),
    //     .i_rdata_ready  (1'b1), // Arbiter luon ready nhan

    //     // --- Downstream Interface (L2 <-> L3) ---
    //     .o_mem_req_valid    (o_mem_req_valid),
    //     .i_mem_req_ready    (i_mem_req_ready),
    //     .o_mem_req_cmd      (o_mem_req_cmd),
    //     .o_mem_req_addr     (o_mem_req_addr),

    //     .o_mem_wdata        (o_mem_wdata),
    //     .o_mem_wdata_valid  (o_mem_wdata_valid),
    //     .o_mem_wdata_last   (o_mem_wdata_last),
    //     .i_mem_wdata_ready  (i_mem_wdata_ready),

    //     .i_mem_rdata_valid  (i_mem_rdata_valid),
    //     .i_mem_rdata_last   (i_mem_rdata_last),
    //     .i_mem_rdata        (i_mem_rdata),
    //     .o_mem_rdata_ready  (o_mem_rdata_ready),

    //     // --- Snoop External ---
    //     .i_ext_snoop_valid  (i_snoop_valid),
    //     .i_ext_snoop_addr   (i_snoop_addr),
    //     .i_ext_snoop_type   (i_snoop_type),
    //     .o_ext_snoop_hit    (o_snoop_hit),
    //     .o_ext_snoop_dirty  (o_snoop_dirty),
    //     .o_ext_snoop_data   (o_snoop_data),

    //     // --- Snoop Internal (L2 -> L1 D-Cache) ---
    //     .o_int_snoop_valid  (int_snoop_valid),
    //     .o_int_snoop_addr   (int_snoop_addr),
    //     .o_int_snoop_type   (int_snoop_type),
    //     .i_int_snoop_hit    (int_snoop_hit),
    //     .i_int_snoop_dirty  (int_snoop_dirty),
    //     .i_int_snoop_data   (int_snoop_data)
    // );

endmodule