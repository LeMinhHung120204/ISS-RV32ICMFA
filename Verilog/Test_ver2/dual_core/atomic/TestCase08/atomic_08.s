# Group: atomic | TestCase: 08 (TC38)
# Description: SC Retry Loop (Spinning)
# Core 0 tries to increment until successful while Core 1 interferes periodically.
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
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

retry:
    lr.w t1, (a0)
    addi t1, t1, 1
    sc.w t2, t1, (a0)
    bnez t2, retry       # Loop until sc.w succeeds
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t3, 0xBAD
    sw t3, 0(a0)         # Cause at least one failure
    sw t3, 0(a0)
    
1:  lw t2, 0(a1)
    li t4, 2
    bne t2, t4, 1b       # Wait for Core 0 to finally succeed
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
shared_val:   .word 0x0
sync_flags:   .word 0x0, 0x0
system_stacks:.skip 2048
