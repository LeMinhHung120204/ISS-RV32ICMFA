# Group: atomic | TestCase: 05 (TC35)
# Description: LR.W / SC.W Success Case
# Core 0 executes LR then SC without interference from Core 1.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024
    mul t1, t0, t1
    add sp, sp, t1
    la a0, shared_val
    
    beqz t0, core0_main
    j park_core

core0_main:
    lr.w t1, (a0)
    addi t1, t1, 1
    sc.w t2, t1, (a0)
    
    # sc.w writes 0 to rd on success
    bnez t2, fail
    
    lw t3, 0(a0)
    li t4, 1
    bne t3, t4, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
shared_val:   .word 0x0
system_stacks:.skip 2048
