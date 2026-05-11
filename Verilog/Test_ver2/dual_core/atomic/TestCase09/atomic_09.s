# Group: atomic | TestCase: 09 (TC39)
# Description: Atomic Burst
# Stress testing the interconnect by slamming AMO instructions.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024
    mul t1, t0, t1
    add sp, sp, t1
    la a0, block_data
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 50
    li t1, 1
2:  amoadd.w zero, t1, 0(a0)
    amoadd.w zero, t1, 4(a0)
    amoadd.w zero, t1, 8(a0)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    1: lw t2, 4(a1); li t3, 2; bne t2, t3, 1b
    j check_result

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 50
    li t1, 2
2:  amoadd.w zero, t1, 0(a0)
    amoadd.w zero, t1, 4(a0)
    amoadd.w zero, t1, 8(a0)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    1: lw t2, 0(a1); li t3, 2; bne t2, t3, 1b
    j pass_end

check_result:
    # 50*1 + 50*2 = 150
    lw t1, 0(a0)
    li t2, 150
    bne t1, t2, fail
pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
block_data:   .word 0, 0, 0
sync_flags:   .word 0, 0
system_stacks:.skip 2048
