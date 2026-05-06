# Group: atomic | TestCase: 07 (TC37)
# Description: LR.W / SC.W ABA Problem
# Core 1 changes value A->B->A. SC must still fail due to cache invalidation.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024
    mul t1, t0, t1
    add sp, sp, t1
    la a0, shared_val
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    lr.w t1, (a0)        # Reserve (Value is A = 5)
    
    li t2, 1; sw t2, 0(a1)
1:  lw t3, 4(a1); beqz t3, 1b
    
    addi t1, t1, 1
    sc.w t2, t1, (a0)    # Value is back to A, but cache was invalidated. MUST FAIL.
    
    beqz t2, fail
    j pass_end

core1_main:
1:  lw t2, 0(a1); beqz t2, 1b
    
    li t3, 99
    sw t3, 0(a0)         # Change to B
    li t3, 5
    sw t3, 0(a0)         # Change back to A
    
    li t2, 1; sw t2, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
shared_val:   .word 5
sync_flags:   .word 0x0, 0x0
system_stacks:.skip 2048
