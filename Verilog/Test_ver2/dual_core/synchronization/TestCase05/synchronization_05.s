# Group: synchronization | TestCase: 05 (TC55)
# Description: Soft_Barrier (Software Sense-Reversing Barrier)
# Ensures two cores can wait for each other at a specific execution point.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, barrier_cnt
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    # Do some work
    li t0, 500
1:  addi t0, t0, -1; bnez t0, 1b

    # Arrive at barrier
    li t1, 1
    amoadd.w zero, t1, (a1)
    
    # Wait for count to reach 2
2:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 2b
    
    j pass_end

core1_main:
    # Do different amount of work
    li t0, 1500
1:  addi t0, t0, -1; bnez t0, 1b

    # Arrive at barrier
    li t1, 1
    amoadd.w zero, t1, (a1)
    
    # Wait for count to reach 2
2:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 2b

    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
barrier_cnt:.word 0
system_stacks:.skip 2048
