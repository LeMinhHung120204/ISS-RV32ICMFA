`timescale 1ns/1ps
module tb_moesi;
    // Local copy of states (phải giống trong DUT)
    localparam  STATE_M = 3'd0,
                STATE_O = 3'd1,
                STATE_E = 3'd2,
                STATE_S = 3'd3,
                STATE_I = 3'd4;

    // DUT inputs
    reg [2:0] current_state;
    reg       share;
    reg       cpu_req_valid;
    reg       cpu_hit;
    reg       cpu_rw;           // 1: write, 0: read
    reg       bus_snoop_valid;
    reg       snoop_hit;
    reg       bus_rw;           // 1: write snoop (BusRdX/BusWr), 0: read snoop (BusRd)

    // DUT outputs
    wire      is_dirty;
    wire      is_unique;
    wire      is_owner;
    wire [2:0] next_state;

    // Instantiate DUT
    moesi_controller dut (
        .current_state   (current_state),
        .share           (share),
        .cpu_req_valid   (cpu_req_valid),
        .cpu_hit         (cpu_hit),
        .cpu_rw          (cpu_rw),
        .bus_snoop_valid (bus_snoop_valid),
        .snoop_hit       (snoop_hit),
        .bus_rw          (bus_rw),
        .is_dirty        (is_dirty),
        .is_unique       (is_unique),
        .is_owner        (is_owner),
        .next_state      (next_state)
    );

    // Task in ra trạng thái cho dễ debug
    task show_status(input [255:0] msg);
    begin
        $display("[%0t] %s", $time, msg);
        $display("    current_state = %0d, next_state = %0d", current_state, next_state);
        $display("    is_dirty=%0b, is_unique=%0b, is_owner=%0b\n",
                 is_dirty, is_unique, is_owner);
    end
    endtask

    initial begin
        current_state    = STATE_I;
        share            = 0;
        cpu_req_valid    = 0;
        cpu_hit          = 0;
        cpu_rw           = 0;
        bus_snoop_valid  = 0;
        snoop_hit        = 0;
        bus_rw           = 0;
        #5;

        // ----------------------------------------------------
        // TEST 1: CPU Read Miss, không share -> I -> E
        // ----------------------------------------------------
        current_state    = STATE_I;
        share            = 0;            // không có core khác giữ
        cpu_req_valid    = 1;
        cpu_hit          = 0;            // miss
        cpu_rw           = 0;            // read
        bus_snoop_valid  = 0;
        snoop_hit        = 0;
        #1;
        show_status("Test 1: CPU Read Miss từ I, không share (expect next_state = E)");

        // ----------------------------------------------------
        // TEST 2: CPU Read Miss, có share -> I -> S
        // ----------------------------------------------------
        current_state    = STATE_I;
        share            = 1;            // có core khác giữ
        cpu_req_valid    = 1;
        cpu_hit          = 0;
        cpu_rw           = 0;            // read
        bus_snoop_valid  = 0;
        snoop_hit        = 0;
        #1;
        show_status("Test 2: CPU Read Miss từ I, share=1 (expect next_state = S)");

        // ----------------------------------------------------
        // TEST 3: CPU Write Miss -> I -> M
        // ----------------------------------------------------
        current_state    = STATE_I;
        cpu_req_valid    = 1;
        cpu_hit          = 0;
        cpu_rw           = 1;            // write
        share            = 0;            // share không quan tr�?ng ở write miss
        bus_snoop_valid  = 0;
        snoop_hit        = 0;
        #1;
        show_status("Test 3: CPU Write Miss từ I (expect next_state = M)");

        // ----------------------------------------------------
        // TEST 4: CPU Write Hit ở S -> M
        // ----------------------------------------------------
        current_state    = STATE_S;
        cpu_req_valid    = 1;
        cpu_hit          = 1;
        cpu_rw           = 1;            // write hit
        bus_snoop_valid  = 0;
        snoop_hit        = 0;
        #1;
        show_status("Test 4: CPU Write Hit từ S (expect next_state = M)");

        // ----------------------------------------------------
        // TEST 5: Snoop Read (BusRd) khi đang M -> O
        // ----------------------------------------------------
        current_state    = STATE_M;
        cpu_req_valid    = 0;
        bus_snoop_valid  = 1;
        snoop_hit        = 1;
        bus_rw           = 0;            // read snoop
        #1;
        show_status("Test 5: Snoop Read khi state = M (expect next_state = O)");

        // ----------------------------------------------------
        // TEST 6: Snoop Read (BusRd) khi đang E -> S
        // ----------------------------------------------------
        current_state    = STATE_E;
        cpu_req_valid    = 0;
        bus_snoop_valid  = 1;
        snoop_hit        = 1;
        bus_rw           = 0;
        #1;
        show_status("Test 6: Snoop Read khi state = E (expect next_state = S)");

        // ----------------------------------------------------
        // TEST 7: Snoop Write (BusRdX) khi đang O -> I
        // ----------------------------------------------------
        current_state    = STATE_O;
        cpu_req_valid    = 0;
        bus_snoop_valid  = 1;
        snoop_hit        = 1;
        bus_rw           = 1;            // write snoop
        #1;
        show_status("Test 7: Snoop Write khi state = O (expect next_state = I)");

        // ----------------------------------------------------
        // TEST 8: Kiểm tra flag is_dirty/is_unique/is_owner
        // ----------------------------------------------------
        current_state    = STATE_M;
        cpu_req_valid    = 0;
        bus_snoop_valid  = 0;
        #1;
        show_status("Test 8.1: state = M (dirty=1, unique=1, owner=1 expected)");

        current_state    = STATE_O;
        #1;
        show_status("Test 8.2: state = O (dirty=1, unique=0, owner=1 expected)");

        current_state    = STATE_E;
        #1;
        show_status("Test 8.3: state = E (dirty=0, unique=1, owner=0 expected)");

        current_state    = STATE_S;
        #1;
        show_status("Test 8.4: state = S (dirty=0, unique=0, owner=0 expected)");

        current_state    = STATE_I;
        #1;
        show_status("Test 8.5: state = I (dirty=0, unique=0, owner=0 expected)");

        $finish;
    end

endmodule
