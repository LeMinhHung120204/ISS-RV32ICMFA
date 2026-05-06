# Group: synchronization | TestCase: 09 (TC59)
# Description: Dekker_Alg (Dekker's Algorithm)
# Validates RVWMO consistency using a classic mutual exclusion algorithm.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, flag_A
    la a3, flag_B
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Core 0 execution
    li t1, 1
    sw t1, 0(a2)         # A = 1
    fence rw, rw         # FULL MEMORY BARRIER
    lw t2, 0(a3)         # Read B
    
    la t3, result_A
    sw t2, 0(t3)
    
    li t1, 2; sw t1, 0(a1)
    j wait_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Core 1 execution
    li t1, 1
    sw t1, 0(a3)         # B = 1
    fence rw, rw         # FULL MEMORY BARRIER
    lw t2, 0(a2)         # Read A
    
    la t3, result_B
    sw t2, 0(t3)
    
    li t1, 2; sw t1, 4(a1)
    j wait_end

wait_end:
    csrr t0, mhartid
    bnez t0, pass_end
    
1:  lw t1, 4(a1)
    li t2, 2
    bne t1, t2, 1b
    
    # In a properly fenced system, A and B cannot BOTH be 0
    la t3, result_A
    lw t4, 0(t3)
    la t3, result_B
    lw t5, 0(t3)
    
    or t6, t4, t5
    beqz t6, fail        # If OR is 0, both are 0 -> Consistency Violation!

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
flag_A:  .word 0
.align 6
flag_B:  .word 0
result_A:.word 0
result_B:.word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
