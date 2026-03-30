`timescale 1ns/1ps
module tb_snoop;

    localparam ADDR_W = 32;

    // Clock & reset
    reg clk;
    reg rst_n;

    // DUT inputs
    reg                   snoop_hit;
    reg                   is_unique; // E/M
    reg                   is_dirty;  // O/M
    reg                   is_owner;  // O/M

    reg                   snoop_can_access_ram;

    wire                  tag_we;
    wire                  snoop_busy;

    wire                  bus_rw;
    wire                  bus_snoop_valid;

    // AC channel
    reg                   ACVALID;
    reg  [3:0]            ACSNOOP;
    reg  [2:0]            ACPROT;
    reg  [ADDR_W-1:0]     ACADDR;
    wire                  ACREADY;

    // CR channel
    reg                   CRREADY;
    wire                  CRVALID;
    wire [4:0]            CRRESP;

    // CD channel
    reg                   CDREADY;
    wire                  CDLAST;
    wire                  CDVALID;

    // Instantiate DUT
    snoop_controller #(
        .ADDR_W(ADDR_W)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .snoop_hit          (snoop_hit),
        .is_unique          (is_unique),
        .is_dirty           (is_dirty),
        .is_owner           (is_owner),
        .snoop_can_access_ram (snoop_can_access_ram),
        .tag_we             (tag_we),
        .snoop_busy         (snoop_busy),
        .bus_rw             (bus_rw),
        .bus_snoop_valid    (bus_snoop_valid),
        .ACVALID            (ACVALID),
        .ACSNOOP            (ACSNOOP),
        .ACPROT             (ACPROT),
        .ACADDR             (ACADDR),
        .ACREADY            (ACREADY),
        .CRREADY            (CRREADY),
        .CRVALID            (CRVALID),
        .CRRESP             (CRRESP),
        .CDREADY            (CDREADY),
        .CDLAST             (CDLAST),
        .CDVALID            (CDVALID)
    );

    // Clock gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Simple display task
    task show_resp(input [255:0] name);
    begin
        $display("--------------------------------------------------");
        $display("[%0t] %s", $time, name);
        $display("  ACSNOOP      = %b", ACSNOOP);
        $display("  snoop_hit    = %b, is_unique=%b, is_dirty=%b, is_owner=%b",
                 snoop_hit, is_unique, is_dirty, is_owner);
        $display("  CRRESP       = %b (WU IS PD 0 DT)", CRRESP);
        $display("  bus_snoop_valid=%b, bus_rw=%b, tag_we=%b",
                 bus_snoop_valid, bus_rw, tag_we);
        $display("  CDVALID=%b, CDLAST=%b", CDVALID, CDLAST);
        $display("--------------------------------------------------\n");
    end
    endtask

    // Task: chạy 1 phiên snoop từ AC -> RESP -> (DATA nếu có)
    task automatic do_snoop(
        input [3:0]  snoop_code,
        input        hit,
        input        u,
        input        d,
        input        o,
        input [255:0] name
    );
    begin
        // setup flags
        snoop_hit  = hit;
        is_unique  = u;
        is_dirty   = d;
        is_owner   = o;

        @(negedge clk);
        ACSNOOP    = snoop_code;
        ACADDR     = 32'h1234_0000;
        ACPROT     = 3'b000;
        ACVALID    = 1'b1;

        // Handshake AC in IDLE (ACREADY expected = 1)
        @(negedge clk);
        ACVALID    = 1'b0;

        // chờ phase RESP (CRVALID lên)
        wait (CRVALID == 1'b1);
        @(posedge clk);
        show_resp(name);

        // nếu có data transfer (bit 0 CRRESP)
        if (CRRESP[0]) begin
            wait (CDVALID == 1'b1 && CDLAST == 1'b1);
            @(posedge clk);
            $display("[%0t]   Data phase done (CDLAST seen)\n", $time);
        end

        // chờ snoop_busy = 0 để chắc chắn đã về IDLE
        wait (snoop_busy == 1'b0);
        @(posedge clk);
    end
    endtask

    initial begin
        snoop_hit           = 0;
        is_unique           = 0;
        is_dirty            = 0;
        is_owner            = 0;

        snoop_can_access_ram = 1'b1; // giả sử luôn được cấp quyền
        ACVALID             = 0;
        ACSNOOP             = 4'b0000;
        ACPROT              = 3'b000;
        ACADDR              = 0;
        CRREADY             = 1'b1;   // luôn sẵn sàng nhận RESP
        CDREADY             = 1'b1;   // luôn sẵn sàng nhận DATA

        rst_n               = 0;
        repeat (3) @(posedge clk);
        rst_n               = 1;
        repeat (2) @(posedge clk);

        // ------------------------------------------------
        // TEST 1: ReadShared (0001) khi cache đang M
        //  - hit=1, is_unique=1, is_dirty=1, is_owner=1
        //  - mong đợi: gửi data, PD=1, IS=1, WU=1, không invalidate tag (tag_we=1 để M->O ở moesi_controller)
        // ------------------------------------------------
        do_snoop(4'b0001, 1'b1, 1'b1, 1'b1, 1'b1,
                 "Test 1: ReadShared when state=M (U=1,D=1,O=1)");

        // ------------------------------------------------
        // TEST 2: ReadShared (0001) khi cache đang S
        //  - hit=1, is_unique=0, is_dirty=0, is_owner=0
        //  - mong đợi: không gửi data (CRRESP=0), tag_we=0
        // ------------------------------------------------
        do_snoop(4'b0001, 1'b1, 1'b0, 1'b0, 1'b0,
                 "Test 2: ReadShared when state=S (U=0,D=0,O=0)");

        // ------------------------------------------------
        // TEST 3: ReadUnique (0111) khi cache đang M
        //  - hit=1, U=1,D=1,O=1
        //  - yêu cầu data + invalidate: gửi data, PD=1, IS=0, WU=1, tag_we=1
        // ------------------------------------------------
        do_snoop(4'b0111, 1'b1, 1'b1, 1'b1, 1'b1,
                 "Test 3: ReadUnique when state=M");

        // ------------------------------------------------
        // TEST 4: CleanInvalid (1001) khi cache đang O
        //  - hit=1, U=0,D=1,O=1
        //  - yêu cầu data + invalidate: gửi data bởi Owner, PD=1, IS=0, WU=0, tag_we=1
        // ------------------------------------------------
        do_snoop(4'b1001, 1'b1, 1'b0, 1'b1, 1'b1,
                 "Test 4: CleanInvalid when state=O");

        // ------------------------------------------------
        // TEST 5: MakeInvalid (1101) khi cache đang S
        //  - hit=1, U=0,D=0,O=0
        //  - chỉ invalidate, không gửi data: CRRESP=00000, tag_we=1
        // ------------------------------------------------
        do_snoop(4'b1101, 1'b1, 1'b0, 1'b0, 1'b0,
                 "Test 5: MakeInvalid when state=S (invalidate only)");

        // ------------------------------------------------
        // TEST 6: ReadShared nhưng không hit (miss)
        //  - hit=0 => không gửi data, không PD/IS/WU, không tag_we
        // ------------------------------------------------
        do_snoop(4'b0001, 1'b0, 1'b0, 1'b0, 1'b0,
                 "Test 6: ReadShared with snoop_miss");

        $display("All tests done.");
        $finish;
    end

endmodule
