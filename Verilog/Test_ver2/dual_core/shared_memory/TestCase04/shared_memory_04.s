# Group: shared_memory | TestCase: 04 (TC64)
# Description: False_Shr_Arr (Array False Sharing)
# Core 0 updates even indices, Core 1 updates odd indices in a shared 64B block.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, interleaved_arr
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 100
2:  lw t3, 0(a2); addi t3, t3, 1; sw t3, 0(a2)   # idx 0
    lw t3, 8(a2); addi t3, t3, 1; sw t3, 8(a2)   # idx 2
    lw t3, 16(a2); addi t3, t3, 1; sw t3, 16(a2) # idx 4
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 100
2:  lw t3, 4(a2); addi t3, t3, 1; sw t3, 4(a2)   # idx 1
    lw t3, 12(a2); addi t3, t3, 1; sw t3, 12(a2) # idx 3
    lw t3, 20(a2); addi t3, t3, 1; sw t3, 20(a2) # idx 5
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
interleaved_arr:.space 64  # 16 words in 1 cache line
sync_flags:.word 0, 0
system_stacks:.skip 2048
