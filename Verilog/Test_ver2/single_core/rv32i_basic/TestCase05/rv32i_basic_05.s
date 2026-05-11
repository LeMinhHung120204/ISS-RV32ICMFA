# Group: rv32i_basic | TestCase: 05
# Description: Load-Use Branch Hazard & Negative Value Comparison
# Tests branch prediction stall when relying on a recently loaded negative value.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, test_data
    lw t1, 0(a0)         # Load 0xFFFFFFFF (-1)
    
    # Branch condition relies on Load. Must stall before resolving.
    # Corner case: comparing -1 to 0
    blt t1, x0, pass     # -1 < 0 is TRUE
    
    j fail               # Should not reach here

pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core

.section.data
.align 4
test_data:
  .word 0xFFFFFFFF
