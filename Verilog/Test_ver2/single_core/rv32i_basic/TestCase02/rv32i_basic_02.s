# Group: rv32i_basic | TestCase: 02
# Description: RAW Hazard (Distance 1) & ALU Overflow Boundary
# Tests MEM to EX forwarding with maximum positive/negative values.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    # Corner case: Max positive and Min negative signed values
    lui t1, 0x80000      # t1 = 0x80000000 (Min Signed)
    addi t2, x0, -1      # t2 = 0xFFFFFFFF (-1)
    
    # ALU operation causing sign wrap-around
    add t3, t1, t2       # t3 = 0x7FFFFFFF (Max Signed)
    nop                  # 1 instruction gap (Distance 1)
    
    # Require forwarding from MEM stage
    add t4, t3, x0       # t4 = 0x7FFFFFFF
    
    li x31, 0x7FFFFFFF
    bne t4, x31, fail
pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
