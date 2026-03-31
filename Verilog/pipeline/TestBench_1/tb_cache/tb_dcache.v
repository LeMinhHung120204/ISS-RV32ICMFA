`timescale 1ns/1ps

module tb_dCache;

    // =========================================================================
    // 1. Parameters & Signals
    // =========================================================================
    parameter ADDR_W        = 32;
    parameter DATA_W        = 32;
    parameter NUM_WAYS      = 4;
    parameter NUM_SETS      = 16;
    parameter ID_W          = 2;
    parameter USER_W        = 4;
    parameter STRB_W        = (DATA_W/8);
    
    // Clock & Reset
    reg ACLK;
    reg ARESETn;

    // CPU Interface
    reg                 cpu_req;
    reg                 cpu_we;
    reg                 data_valid;
    reg [ADDR_W-1:0]    CPU_Addr;
    reg [DATA_W-1:0]    cpu_din;
    wire [DATA_W-1:0]   data_rdata;
    wire                cpu_hit;

    // AXI / ACE Interface (Cache <-> L2)
    // AW
    reg                 iAWREADY;
    wire [ID_W-1:0]     oAWID;
    wire [ADDR_W-1:0]   oAWADDR;
    wire [7:0]          oAWLEN;
    wire [2:0]          oAWSIZE;
    wire [1:0]          oAWBURST;
    wire                oAWLOCK;
    wire [3:0]          oAWCACHE;
    wire [2:0]          oAWPROT;
    wire [3:0]          oAWQOS;
    wire [3:0]          oAWREGION;
    wire [USER_W-1:0]   oAWUSER;
    wire                oAWVALID;
    wire [2:0]          oAWSNOOP;
    wire [1:0]          oAWDOMAIN;
    wire [1:0]          oAWBAR;
    wire                oAWUNIQUE;

    // W
    reg                 iWREADY;
    wire [DATA_W-1:0]   oWDATA;
    wire [STRB_W-1:0]   oWSTRB;
    wire                oWLAST;
    wire [USER_W-1:0]   oWUSER;
    wire                oWVALID;

    // B
    reg [ID_W-1:0]      iBID;
    reg [1:0]           iBRESP;
    reg [USER_W-1:0]    iBUSER;
    reg                 iBVALID;
    wire                oBREADY;

    // AR
    reg                 iARREADY;
    wire [ID_W-1:0]     oARID;
    wire [ADDR_W-1:0]   oARADDR;
    wire [7:0]          oARLEN;
    wire [2:0]          oARSIZE;
    wire [1:0]          oARBURST;
    wire                oARLOCK;
    wire [3:0]          oARCACHE;
    wire [2:0]          oARPROT;
    wire [3:0]          oARQOS;
    wire [USER_W-1:0]   oARUSER;
    wire                oARVALID;
    wire [3:0]          oARSNOOP;
    wire [1:0]          oARDOMAIN;
    wire [1:0]          oARBAR;

    // R
    reg [ID_W-1:0]      iRID;
    reg [DATA_W-1:0]    iRDATA;
    reg [3:0]           iRRESP;
    reg                 iRLAST;
    reg [USER_W-1:0]    iRUSER;
    reg                 iRVALID;
    wire                oRREADY;

    // Snoop unused signals
    reg                 iACVALID;
    reg [ADDR_W-1:0]    iACADDR;
    reg [3:0]           iACSNOOP;
    reg [2:0]           iACPROT;
    wire                oACREADY;

    reg                 iCRREADY;
    wire                oCRVALID;
    wire [4:0]          oCRRESP;

    reg                 iCDREADY;
    wire                oCDVALID;
    wire [DATA_W-1:0]   oCDDATA;
    wire                oCDLAST;

    // =========================================================================
    // 2. Instantiate DUT
    // =========================================================================
    dCache #(
        .ADDR_W(ADDR_W), .DATA_W(DATA_W), .NUM_WAYS(NUM_WAYS), .NUM_SETS(NUM_SETS)
    ) dut (
        .ACLK(ACLK), .ARESETn(ARESETn),
        // CPU
        .cpu_req(cpu_req), .cpu_we(cpu_we), .data_valid(data_valid),
        .CPU_Addr(CPU_Addr), .cpu_din(cpu_din),
        .data_rdata(data_rdata), .cpu_hit(cpu_hit),
        // AXI
        .iAWREADY(iAWREADY), .oAWID(oAWID), .oAWADDR(oAWADDR), .oAWLEN(oAWLEN),
        .oAWSIZE(oAWSIZE), .oAWBURST(oAWBURST), .oAWLOCK(oAWLOCK), .oAWCACHE(oAWCACHE),
        .oAWPROT(oAWPROT), .oAWQOS(oAWQOS), .oAWREGION(oAWREGION), .oAWUSER(oAWUSER),
        .oAWVALID(oAWVALID), .oAWSNOOP(oAWSNOOP), .oAWDOMAIN(oAWDOMAIN), .oAWBAR(oAWBAR), .oAWUNIQUE(oAWUNIQUE),
        
        .iWREADY(iWREADY), .oWDATA(oWDATA), .oWSTRB(oWSTRB), .oWLAST(oWLAST),
        .oWUSER(oWUSER), .oWVALID(oWVALID),
        
        .iBID(iBID), .iBRESP(iBRESP), .iBUSER(iBUSER), .iBVALID(iBVALID), .oBREADY(oBREADY),
        
        .iARREADY(iARREADY), .oARID(oARID), .oARADDR(oARADDR), .oARLEN(oARLEN),
        .oARSIZE(oARSIZE), .oARBURST(oARBURST), .oARLOCK(oARLOCK), .oARCACHE(oARCACHE),
        .oARPROT(oARPROT), .oARQOS(oARQOS), .oARUSER(oARUSER), .oARVALID(oARVALID),
        .oARSNOOP(oARSNOOP), .oARDOMAIN(oARDOMAIN), .oARBAR(oARBAR),
        
        .iRID(iRID), .iRDATA(iRDATA), .iRRESP(iRRESP), .iRLAST(iRLAST),
        .iRUSER(iRUSER), .iRVALID(iRVALID), .oRREADY(oRREADY),
        
        .iACVALID(iACVALID), .iACADDR(iACADDR), .iACSNOOP(iACSNOOP), .iACPROT(iACPROT), .oACREADY(oACREADY),
        .iCRREADY(iCRREADY), .oCRVALID(oCRVALID), .oCRRESP(oCRRESP),
        .iCDREADY(iCDREADY), .oCDVALID(oCDVALID), .oCDDATA(oCDDATA), .oCDLAST(oCDLAST)
    );

    // =========================================================================
    // 3. Clock & Reset
    // =========================================================================
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK; // 100MHz
    end

    initial begin
        ARESETn = 0;
        #100;
        ARESETn = 1;
    end

    // =========================================================================
    // 4. Mock Memory / L2 Simulation (Fix Syntax)
    // =========================================================================
    
    // Kh?i t?o t�n hi?u m?c ??nh
    initial begin
        iAWREADY = 0; iWREADY = 0;
        iBID = 0; iBRESP = 0; iBUSER = 0; iBVALID = 0;
        iARREADY = 0;
        iRID = 0; iRDATA = 0; iRRESP = 0; iRLAST = 0; iRUSER = 0; iRVALID = 0;
        iACVALID = 0; iACADDR = 0; iACSNOOP = 0; iACPROT = 0;
        iCRREADY = 1; iCDREADY = 1;
    end

    // --- Bi?n d�ng chung cho loop ---
    integer k; 

    // Process x? l� Read Miss (AR Channel -> R Channel)
    always @(posedge ACLK) begin
        if (oARVALID && !iARREADY) begin
            iARREADY <= 1;
            $display("[MEM] Read Request received at Addr: %h, Len: %d", oARADDR, oARLEN);
        end else begin
            iARREADY <= 0;
        end

        // Tr? d? li?u v? (Refill Line)
        if (oARVALID && iARREADY) begin
            repeat(2) @(posedge ACLK); // Latency
            
            // --- FIX: D�ng v�ng l?p for ki?u Verilog c? ---
            for (k = 0; k <= 15; k = k + 1) begin
                iRVALID <= 1;
                iRDATA  <= 32'hAAAA_0000 + k; 
                iRID    <= oARID;
                if (k == 15) iRLAST <= 1;
                else         iRLAST <= 0;
                
                // --- FIX: Thay do...while b?ng wait loop ---
                @(posedge ACLK); // ??i 1 chu k? ?? ??y t�n hi?u ra
                while (!oRREADY) begin
                    @(posedge ACLK); // N?u cache ch?a nh?n (RREADY=0), ??i ti?p
                end
            end
            
            iRVALID <= 0;
            iRLAST  <= 0;
            $display("[MEM] Refill Done.");
        end
    end

    // Process x? l� Write Miss/WriteBack
    always @(posedge ACLK) begin
        // Handshake AW
        if (oAWVALID && !iAWREADY) begin
            iAWREADY <= 1;
             $display("[MEM] Write Request Addr: %h", oAWADDR);
        end else begin
            iAWREADY <= 0;
        end

        // Handshake W
        if (oWVALID && !iWREADY) begin
            iWREADY <= 1;
        end else begin
            iWREADY <= 0;
        end

        // Tr? Response B
        if (oWVALID && iWREADY && oWLAST) begin
            @(posedge ACLK);
            iBVALID <= 1;
            iBID    <= oAWID;
            iBRESP  <= 0; // OKAY
            
            @(posedge ACLK);
            while (!oBREADY) begin
                @(posedge ACLK);
            end
            
            iBVALID <= 0;
            $display("[MEM] Write Response Sent.");
        end
    end

    // =========================================================================
    // 5. Test Tasks
    // =========================================================================
    
    task cpu_read_task;
        input [ADDR_W-1:0] addr;
        begin
            $display("[CPU] READ Request @ %h at time %t", addr, $time);
            @(posedge ACLK);
            cpu_req     <= 1;
            cpu_we      <= 0;
            CPU_Addr    <= addr;
            data_valid  <= 1; 
            @(posedge ACLK);
            data_valid  <= 0;
            
            wait(cpu_hit); 
            $display("[CPU] READ HIT! Data: %h", data_rdata);
            
            @(posedge ACLK);
            cpu_req     <= 0;
        end
    endtask

    task cpu_write_task;
        input [ADDR_W-1:0] addr;
        input [DATA_W-1:0] data;
        begin
            $display("[CPU] WRITE Request @ %h with Data: %h at time %t", addr, data, $time);
            @(posedge ACLK);
            cpu_req     <= 1;
            cpu_we      <= 1;
            CPU_Addr    <= addr;
            cpu_din     <= data;
            data_valid  <= 1;
            @(posedge ACLK);
            data_valid  <= 0;

            wait(cpu_hit);
            $display("[CPU] WRITE HIT/DONE!");
            
            @(posedge ACLK);
            cpu_req     <= 0;
        end
    endtask

    // =========================================================================
    // 6. Main Test Sequence
    // =========================================================================
    initial begin
        // Kh?i t?o
        cpu_req = 0; cpu_we = 0; data_valid = 0;
        CPU_Addr = 0; cpu_din = 0;

        wait(ARESETn);
        repeat(10) @(posedge ACLK);
        $display("------------------------------------------------");
        $display("STARTING TESTBENCH");
        $display("------------------------------------------------");

        // --- TEST CASE 1: CPU READ MISS ---
        cpu_read_task(32'h0000_1000);
        repeat(5) @(posedge ACLK);

        // --- TEST CASE 2: CPU READ HIT ---
        $display("--- Expecting Immediate HIT ---");
        cpu_read_task(32'h0000_1000);
        repeat(5) @(posedge ACLK);

        // --- TEST CASE 3: CPU WRITE HIT ---
        cpu_write_task(32'h0000_1000, 32'hDEAD_BEEF);
        repeat(5) @(posedge ACLK);

        // --- TEST CASE 4: VERIFY WRITE ---
        cpu_read_task(32'h0000_1000);
        if (data_rdata === 32'hDEAD_BEEF) 
            $display("SUCCESS: Data Match!");
        else 
            $display("ERROR: Data Mismatch! Expected DEAD_BEEF, got %h", data_rdata);

        // --- TEST CASE 5: CPU WRITE MISS ---
        $display("--- Write Miss Test ---");
        cpu_write_task(32'h0000_2000, 32'hCAFE_F00D);
        
        repeat(50) @(posedge ACLK);
        $finish;
    end

endmodule