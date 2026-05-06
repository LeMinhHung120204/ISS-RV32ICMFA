# Group: shared_memory | TestCase: 05 (TC65)
# Description: Mem_Padding (False Sharing Fix)
# Adding padding to separate variables into DIFFERENT cache lines. Should execute fast.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, padded_var0
    la a3, padded_var1
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 1000
2:  lw t3, 0(a2)
    addi t3, t3, 1
    sw t3, 0(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 1000
2:  lw t3, 0(a3)         # Accessing a3 (completely different cache line)
    addi t3, t3, 1
    sw t3, 0(a3)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
padded_var0:.word 0
.align 6                 # Force next variable into the next 64B block
padded_var1:.word 0
sync_flags: .word 0, 0
system_stacks:.skip 2048
