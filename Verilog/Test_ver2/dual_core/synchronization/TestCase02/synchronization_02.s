# Group: synchronization | TestCase: 02 (TC52)
# Description: TTAS_Lock (Test-and-Test-and-Set Lock)
# Optimizes bus traffic by spinning on a volatile read (lw) before trying amoswap.w.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, ttas_lock
    la a3, shared_counter
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 100
    
acquire_lock:
    # 1. TEST phase (Wait until lock seems free without atomic writes)
1:  lw t2, 0(a2)
    bnez t2, 1b
    
    # 2. TEST-AND-SET phase (Attempt to acquire)
    li t1, 1
    amoswap.w t2, t1, (a2)
    bnez t2, acquire_lock  # If failed, go back to TEST phase
    
    # Critical section
    lw t3, 0(a3)
    addi t3, t3, 1
    sw t3, 0(a3)
    
    # Release lock
    amoswap.w zero, zero, (a2)
    
    addi t0, t0, -1
    bnez t0, acquire_lock
    
    li t1, 2; sw t1, 0(a1)
    j wait_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 100
acquire_lock1:
1:  lw t2, 0(a2)
    bnez t2, 1b
    li t1, 1
    amoswap.w t2, t1, (a2)
    bnez t2, acquire_lock1
    
    # Critical section
    lw t3, 0(a3)
    addi t3, t3, 1
    sw t3, 0(a3)
    
    # Release lock
    amoswap.w zero, zero, (a2)
    addi t0, t0, -1
    bnez t0, acquire_lock1
    
    li t1, 2; sw t1, 4(a1)
    j wait_end

wait_end:
    csrr t0, mhartid
    bnez t0, pass_end
1:  lw t1, 4(a1)
    li t2, 2
    bne t1, t2, 1b
    lw t3, 0(a3)
    li t4, 200
    bne t3, t4, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
ttas_lock:    .word 0
shared_counter:.word 0
sync_flags:   .word 0, 0
system_stacks:.skip 2048
