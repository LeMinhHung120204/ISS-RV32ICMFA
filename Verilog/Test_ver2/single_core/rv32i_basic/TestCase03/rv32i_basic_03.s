# Group: rv32i_basic | TestCase: 03
# Description: RAW Hazard (Distance 2) & Multiple In-Flight Overwrites
# Tests WB to EX forwarding when the same register is updated multiple times.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    # Corner case: Multiple writes to t1 in pipeline
    addi t1, x0, 1
    addi t1, x0, 2
    addi t1, x0, 3       # This is the valid one
    
    nop                  
    nop                  # 2 instructions gap (Distance 2)
    
    # Forwarding must pick the most recent t1 (which is 3)
    add t2, t1, x0       # t2 = 3
    
    li x31, 3
    bne t2, x31, fail
pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
