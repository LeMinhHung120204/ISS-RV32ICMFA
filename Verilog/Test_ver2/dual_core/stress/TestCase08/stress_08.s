# Group: stress | TestCase: 08 (TC88)
# Description: Rand_Stride
# Implements a pseudo-random memory stride to defeat Hardware Prefetchers.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a2, rand_array
    bnez t0, park_core

core0_main:
    li t0, 50            # Iterations
    li t1, 1             # Seed (x_n)

rand_loop:
    # LCG: x_{n+1} = (x_n * 5 + 1) mod 64
    li t2, 5
    mul t1, t1, t2
    addi t1, t1, 1
    andi t1, t1, 63      # Modulo 64
    
    # Use pseudo-random number as word offset
    slli t3, t1, 2
    add t4, a2, t3
    
    # Access Memory
    lw t5, 0(t4)
    addi t5, t5, 1
    sw t5, 0(t4)
    
    addi t0, t0, -1
    bnez t0, rand_loop

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
rand_array:.space 256   # 64 words
system_stacks:.skip 2048
