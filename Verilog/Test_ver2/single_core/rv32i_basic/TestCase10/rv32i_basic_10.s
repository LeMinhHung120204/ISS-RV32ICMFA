# Group: rv32i_basic | TestCase: 10
# Description: WAR Hazard (Write-After-Read) & Pipeline Safety
# Tests that read operations safely retrieve old values before overwrite.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    li t1, 10
    
    # Read phase
    add t2, t1, x0           # t2 MUST read 10
    
    # Write phase immediately after
    addi t1, x0, 20          # t1 becomes 20
    
    # Corner case verify
    sub t3, t2, t1           # t3 = 10 - 20 = -10
    
    li x31, -10
    bne t3, x31, fail
pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
