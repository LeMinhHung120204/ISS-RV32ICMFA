# Group: rv32i_basic | TestCase: 01
# Description: RAW Hazard (Distance 0) & Zero Register (x0) Corner Case
# Tests EX to EX forwarding and ensures writes to x0 are discarded.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    # Corner case: Try to overwrite x0 (must remain 0)
    addi x0, x0, 10
    
    # RAW Hazard distance 0
    li t1, 15
    li t2, 25
    add t3, t1, t2       # t3 = 40 (computed in EX)
    sub t4, t3, t1       # t4 = 25 (requires t3 from EX->ID/EX)
    
    # Use x0 in calculation, must act as 0, not 10
    add t5, t4, x0       # t5 = 25 + 0 = 25

    li x31, 25
    bne t5, x31, fail
pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
