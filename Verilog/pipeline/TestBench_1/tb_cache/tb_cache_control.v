`timescale 1ns/1ps

module tb_cache_control;

    localparam DATA_W    = 32;
    localparam ADDR_W    = 32;
    localparam ID_W      = 2;
    localparam USER_W    = 4;
    localparam STRB_W    = (DATA_W/8);

    // Clock, reset
    reg clk;
    reg rst_n;

    // Inputs to DUT
    reg           snoop_busy;
    wire          snoop_can_access_ram;
    wire          wb_error;

    reg           cpu_req;
    reg           cpu_we;
    reg           hit;
    reg           victim_dirty;
    reg           is_valid;
    reg  [2:0]    current_moesi_state;

    // AXI/ACE inputs
    reg                   iAWREADY;
    reg                   iWREADY;
    reg  [ID_W-1:0]       iBID;
    reg  [1:0]            iBRESP;
    reg  [USER_W-1:0]     iBUSER;
    reg                   iBVALID;

    reg                   iARREADY;
    reg  [ID_W-1:0]       iRID;
    reg  [DATA_W-1:0]     iRDATA;
    reg  [3:0]            iRRESP;
    reg                   iRLAST;
    reg  [USER_W-1:0]     iRUSER;
    reg                   iRVALID;

    // AXI/ACE outputs from DUT
    wire [ID_W-1:0]       oAWID;
    wire [ADDR_W-1:0]     oAWADDR;
    wire [7:0]            oAWLEN;
    wire [2:0]            oAWSIZE;
    wire [1:0]            oAWBURST;
    wire                  oAWLOCK;
    wire [3:0]            oAWCACHE;
    wire [2:0]            oAWPROT;
    wire [3:0]            oAWQOS;
    wire [3:0]            oAWREGION;
    wire [USER_W-1:0]     oAWUSER;
    wire                  oAWVALID;
    wire [2:0]            oAWSNOOP;
    wire [1:0]            oAWDOMAIN;
    wire [1:0]            oAWBAR;
    wire                  oAWUNIQUE;

    wire [ID_W-1:0]       oWID;
    wire [DATA_W-1:0]     oWDATA;
    wire [STRB_W-1:0]     oWSTRB;
    wire                  oWLAST;
    wire [USER_W-1:0]     oWUSER;
    wire                  oWVALID;

    wire [ID_W-1:0]       iBID_unused = iBID;
    wire [USER_W-1:0]     iBUSER_unused = iBUSER;

    wire [ID_W-1:0]       oARID;
    wire [ADDR_W-1:0]     oARADDR;
    wire [7:0]            oARLEN;
    wire [3:0]            oARSIZE;
    wire [1:0]            oARBURST;
    wire                  oARLOCK;
    wire [3:0]            oARCACHE;
    wire [2:0]            oARPROT;
    wire [3:0]            oARQOS;
    wire [USER_W-1:0]     oARUSER;
    wire                  oARVALID;
    wire [3:0]            oARSNOOP;
    wire [1:0]            oARDOMAIN;
    wire [1:0]            oARBAR;

    wire [ID_W-1:0]       iRID_unused = iRID;
    wire [DATA_W-1:0]     iRDATA_unused = iRDATA;
    wire [USER_W-1:0]     iRUSER_unused = iRUSER;

    wire                  oRREADY;

    // Datapath control outputs
    wire                  data_we;
    wire                  tag_we;
    wire                  cache_busy;
    wire                  is_shared_response;

    // Instantiate DUT, rút g�?n BURST_LEN=3 cho TB chạy nhanh (4 beat)
    cache_controller #(
        .DATA_W    (DATA_W),
        .ADDR_W    (ADDR_W),
        .ID_W      (ID_W),
        .USER_W    (USER_W),
        .STRB_W    (STRB_W),
        .BURST_LEN (3)           // 4 beat thay vì 16 beat cho dễ test
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .snoop_busy         (snoop_busy),
        .snoop_can_access_ram (snoop_can_access_ram),
        .wb_error           (wb_error),
        .cpu_req            (cpu_req),
        .cpu_we             (cpu_we),
        .hit                (hit),
        .victim_dirty       (victim_dirty),
        .is_valid           (is_valid),
        .current_moesi_state(current_moesi_state),

        .data_we            (data_we),
        .tag_we             (tag_we),
        .cache_busy         (cache_busy),
        .is_shared_response (is_shared_response),

        .oAWID              (oAWID),
        .oAWADDR            (oAWADDR),
        .oAWLEN             (oAWLEN),
        .oAWSIZE            (oAWSIZE),
        .oAWBURST           (oAWBURST),
        .oAWLOCK            (oAWLOCK),
        .oAWCACHE           (oAWCACHE),
        .oAWPROT            (oAWPROT),
        .oAWQOS             (oAWQOS),
        .oAWREGION          (oAWREGION),
        .oAWUSER            (oAWUSER),
        .oAWVALID           (oAWVALID),
        .iAWREADY           (iAWREADY),
        .oAWSNOOP           (oAWSNOOP),
        .oAWDOMAIN          (oAWDOMAIN),
        .oAWBAR             (oAWBAR),
        .oAWUNIQUE          (oAWUNIQUE),

        .oWID               (oWID),
        .oWDATA             (oWDATA),
        .oWSTRB             (oWSTRB),
        .oWLAST             (oWLAST),
        .oWUSER             (oWUSER),
        .oWVALID            (oWVALID),
        .iWREADY            (iWREADY),

        .iBID               (iBID),
        .iBRESP             (iBRESP),
        .iBUSER             (iBUSER),
        .iBVALID            (iBVALID),
        .oBREADY            (oBREADY),

        .oARID              (oARID),
        .oARADDR            (oARADDR),
        .oARLEN             (oARLEN),
        .oARSIZE            (oARSIZE),
        .oARBURST           (oARBURST),
        .oARLOCK            (oARLOCK),
        .oARCACHE           (oARCACHE),
        .oARPROT            (oARPROT),
        .oARQOS             (oARQOS),
        .oARUSER            (oARUSER),
        .oARVALID           (oARVALID),
        .iARREADY           (iARREADY),
        .oARSNOOP           (oARSNOOP),
        .oARDOMAIN          (oARDOMAIN),
        .oARBAR             (oARBAR),

        .iRID               (iRID),
        .iRDATA             (iRDATA),
        .iRRESP             (iRRESP),
        .iRLAST             (iRLAST),
        .iRUSER             (iRUSER),
        .iRVALID            (iRVALID),
        .oRREADY            (oRREADY)
    );

    // Clock gen
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // Helper: in ra 1 dòng tóm tắt
    task show_status(input [255:0] msg);
    begin
        $display("--------------------------------------------------");
        $display("[%0t] %s", $time, msg);
        $display("  cache_busy=%b, data_we=%b, tag_we=%b, wb_error=%b", 
                 cache_busy, data_we, tag_we, wb_error);
        $display("  oARVALID=%b, oARSNOOP=%b, oAWVALID=%b, oAWSNOOP=%b",
                 oARVALID, oARSNOOP, oAWVALID, oAWSNOOP);
        $display("  snoop_can_access_ram=%b", snoop_can_access_ram);
        $display("--------------------------------------------------\n");
    end
    endtask

    initial begin
        // Default input values
        snoop_busy          = 1'b0;
        cpu_req             = 1'b0;
        cpu_we              = 1'b0;
        hit                 = 1'b0;
        victim_dirty        = 1'b0;
        is_valid            = 1'b0;
        current_moesi_state = 3'd0;

        iAWREADY            = 1'b1;
        iWREADY             = 1'b1;
        iBID                = 0;
        iBRESP              = 2'b00;
        iBUSER              = 0;
        iBVALID             = 1'b0;

        iARREADY            = 1'b1;
        iRID                = 0;
        iRDATA              = 0;
        iRRESP              = 4'b0000;
        iRLAST              = 1'b0;
        iRUSER              = 0;
        iRVALID             = 1'b0;

        // Reset
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ----------------- TEST 1: Read hit (state M) -----------------
        current_moesi_state = 3'd0; // M
        hit          = 1'b1;
        cpu_we       = 1'b0; // read
        is_valid     = 1'b1;
        victim_dirty = 1'b0;

        @(negedge clk);
        cpu_req = 1'b1;
        @(posedge clk);
        cpu_req = 1'b0;
        repeat (2) @(posedge clk);
        show_status("Test 1: Read hit in M (expect: no AXI, cache_busy=0)");

        // ----------------- TEST 2: Write hit in S -> upgrade -----------------
        current_moesi_state = 3'd3; // S
        hit          = 1'b1;
        cpu_we       = 1'b1;
        is_valid     = 1'b1;

        @(negedge clk);
        cpu_req = 1'b1;
        @(posedge clk);
        cpu_req = 1'b0;

        // Ch�? ARVALID, check ARSNOOP = CleanUnique (1011)
        wait (oARVALID == 1'b1);
        @(posedge clk);
        show_status("Test 2: Write hit in S (expect ARVALID=1, oARSNOOP=1011)");

        // Sinh 1 beat RDATA với RLAST=1, RRESP bit3=1 => Shared
        iRVALID = 1'b1;
        iRLAST  = 1'b1;
        iRRESP  = 4'b1000;
        @(posedge clk);
        iRVALID = 1'b0;
        iRLAST  = 1'b0;
        repeat (2) @(posedge clk);
        show_status("Test 2 (cont): After RRESP, expect go UPDATE -> TAG_CHECK/IDLE");

        // ----------------- TEST 3: Read miss, victim clean -----------------
        hit          = 1'b0;
        is_valid     = 1'b0; // victim invalid/clean
        victim_dirty = 1'b0;
        cpu_we       = 1'b0; // read miss

        @(negedge clk);
        cpu_req = 1'b1;
        @(posedge clk);
        cpu_req = 1'b0;

        // Ch�? ARVALID
        wait (oARVALID == 1'b1);
        @(posedge clk);
        show_status("Test 3: Read miss, victim clean (expect ARVALID=1, ARSNOOP=ReadShared 0001)");

        // R beat
        iRVALID = 1'b1;
        iRLAST  = 1'b1;
        iRRESP  = 4'b0000; // non-shared
        @(posedge clk);
        iRVALID = 1'b0;
        iRLAST  = 1'b0;
        repeat (2) @(posedge clk);

        // ----------------- TEST 4: Read miss, victim dirty, WB OK -----------------
        hit          = 1'b0;
        is_valid     = 1'b1;
        victim_dirty = 1'b1;
        cpu_we       = 1'b0;

        @(negedge clk);
        cpu_req = 1'b1;
        @(posedge clk);
        cpu_req = 1'b0;

        // WB_AW -> WB_W -> WB_B
        wait (oAWVALID == 1'b1);
        @(posedge clk);
        show_status("Test 4: WB_AW active (expect oAWVALID=1, oAWSNOOP=WriteBack 011)");

        // Giả sử vài cycle sau WB_W xong, BVALID=1 & BRESP OK
        repeat (5) @(posedge clk);
        iBVALID = 1'b1;
        iBRESP  = 2'b00; // OKAY
        @(posedge clk);
        iBVALID = 1'b0;

        // Sau WB_B -> ALLOC_AR -> ARVALID
        wait (oARVALID == 1'b1);
        @(posedge clk);
        show_status("Test 4 (cont): After WB, expect ARVALID for linefill");

        // R beat cho linefill
        iRVALID = 1'b1;
        iRLAST  = 1'b1;
        iRRESP  = 4'b0000;
        @(posedge clk);
        iRVALID = 1'b0;
        iRLAST  = 1'b0;
        repeat (2) @(posedge clk);

        // ----------------- TEST 5: WB error -> FAULT -----------------
        hit          = 1'b0;
        is_valid     = 1'b1;
        victim_dirty = 1'b1;
        cpu_we       = 1'b0;

        @(negedge clk);
        cpu_req = 1'b1;
        @(posedge clk);
        cpu_req = 1'b0;

        // WB address
        wait (oAWVALID == 1'b1);
        @(posedge clk);

        // BVALID với error (BRESP[1]=1)
        repeat (5) @(posedge clk);
        iBVALID = 1'b1;
        iBRESP  = 2'b10; // SLVERR (error)
        @(posedge clk);
        iBVALID = 1'b0;
        repeat (2) @(posedge clk);

        show_status("Test 5: WB error (expect wb_error=1, stay FAULT)");

        $display("All tests done.");
        $finish;
    end

endmodule
