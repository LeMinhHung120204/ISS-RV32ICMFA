module dual_core #(
    // Core Configuration
    parameter MEM_BASE      = 32'h0000_0000     // Memory base address
,   parameter ID_W          = 1                 // Transaction ID width (2 cores)

    // Core A Instruction Memory
,   parameter CODE_A_START  = 32'h0000_0000     // Core A instruction base

    // Core B Instruction Memory
,   parameter CODE_B_START  = 32'h0000_4000     // Core B instruction base

    // Shared Data Memory
,   parameter DATA_START    = 32'h0001_0000     // Shared data base

    // Cache Configuration
,   parameter NUM_WAYS      = 4                 // Cache associativity
,   parameter NUM_SETS      = 16                // L1 cache sets
,   parameter NUM_SETS_L2   = 32                // L2 cache sets
,   parameter WORD_OFF_W    = 4                 // Word offset (16 words/line)
,   parameter BYTE_OFF_W    = 2                 // Byte offset (4 bytes/word)
,   parameter DATA_W        = 32                // Data width
,   parameter STRB_W        = DATA_W/8          // Write strobe width
)(

);
endmodule 
