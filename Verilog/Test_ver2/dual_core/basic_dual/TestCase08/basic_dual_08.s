# Group: basic_dual | TestCase: 08 (TC28)
# Description: Register Isolation
# Extensively tests that registers x1-x31 in Core 0 don't affect Core 1.
.section.text
.global _start
_start:
    csrr t0, mhartid
    beqz t0, core0_main

core1_main:
    # Fill registers with 0x55555555
    li t1, 0x55555555
    mv x1, t1; mv x2, t1; mv x3, t1; mv x4, t1
    mv x5, t1; mv x6, t1; mv x7, t1; mv x8, t1
    #... Wait to ensure overlap in time
    li t2, 100
1:  addi t2, t2, -1
    bnez t2, 1b
    
    # Check if any changed
    bne x1, t1, fail
    bne x8, t1, fail
    j pass_end

core0_main:
    # Fill registers with 0xAAAAAAAA
    li t1, 0xAAAAAAAA
    mv x1, t1; mv x2, t1; mv x3, t1; mv x4, t1
    mv x5, t1; mv x6, t1; mv x7, t1; mv x8, t1
    #... Wait to ensure overlap in time
    li t2, 100
1:  addi t2, t2, -1
    bnez t2, 1b
    
    # Check if any changed
    bne x1, t1, fail
    bne x8, t1, fail
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
