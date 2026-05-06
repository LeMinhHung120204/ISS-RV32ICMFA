# Group: stress | TestCase: 02 (TC82)
# Description: Cache_Thrash
# Accesses memory with large strides (e.g., 32KB) to force continuous cache evictions.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, thrash_mem
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 100
    li t1, 16384         # 16KB stride (likely exceeds L1 way capacity)
2:  
    add t3, a2, zero
    lw t4, 0(t3)         # Access Way 0
    add t3, t3, t1
    lw t4, 0(t3)         # Access Way 1
    add t3, t3, t1
    lw t4, 0(t3)         # Access Way 2
    add t3, t3, t1
    lw t4, 0(t3)         # Eviction happens here
    
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Do the same on another memory space to crash the interconnect
    li t0, 100
    li t1, 16384         
2:  add t3, a2, zero
    addi t3, t3, 64      # Offset by 1 cache line
    lw t4, 0(t3)         
    add t3, t3, t1
    lw t4, 0(t3)         
    add t3, t3, t1
    lw t4, 0(t3)         
    add t3, t3, t1
    lw t4, 0(t3)         
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
sync_flags:.word 0, 0
.align 12                # Align to 4KB page
thrash_mem:.space 131072 # 128KB memory pool
system_stacks:.skip 2048
