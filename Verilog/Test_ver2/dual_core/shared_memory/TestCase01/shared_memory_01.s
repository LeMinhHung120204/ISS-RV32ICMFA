# Group: shared_memory | TestCase: 01 (TC61)
# Description: True_Share_R (Continuous read on same array)
# Both cores read the same block simultaneously. Cache lines should maintain Shared (S) state.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, shared_array
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Core 0 reads array 1000 times
    li t0, 1000
2:  lw t1, 0(a2)
    lw t2, 4(a2)
    lw t3, 8(a2)
    lw t4, 12(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Core 1 reads array 1000 times concurrently
    li t0, 1000
2:  lw t1, 0(a2)
    lw t2, 4(a2)
    lw t3, 8(a2)
    lw t4, 12(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
shared_array:.word 10, 20, 30, 40
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
