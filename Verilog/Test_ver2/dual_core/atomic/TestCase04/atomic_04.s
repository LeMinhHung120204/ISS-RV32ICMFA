# Group: atomic | TestCase: 04 (TC34)
# Description: AMOMAXU.W / AMOMIN.W
# Tests unsigned max selection atomically.
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

    li t1, 150
    amomaxu.w zero, t1, (a0)   
    
    li t1, 2; sw t1, 0(a1)
    1: lw t2, 4(a1); li t3, 2; bne t2, t3, 1b
    j check_result

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t1, 200
    amomaxu.w zero, t1, (a0)   
    
    li t1, 2; sw t1, 4(a1)
    1: lw t2, 0(a1); li t3, 2; bne t2, t3, 1b
    j pass_end

check_result:
    lw t1, 0(a0)
    li t2, 200                 # 200 > 150 > 50, so max must be 200
    bne t1, t2, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
shared_val:   .word 50
sync_flags:   .word 0x0, 0x0
system_stacks:.skip 2048
