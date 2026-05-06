# Group: shared_memory | TestCase: 02 (TC62)
# Description: True_Share_W (Continuous write on same address)
# Triggers continuous bus contention and ping-pong of Modified/Invalid states.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, target_var
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Core 0 writes 0xAAAA continuously
    li t0, 1000
    li t3, 0xAAAA
2:  sw t3, 0(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Core 1 writes 0xBBBB continuously
    li t0, 1000
    li t3, 0xBBBB
2:  sw t3, 0(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_var:  .word 0x0
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
