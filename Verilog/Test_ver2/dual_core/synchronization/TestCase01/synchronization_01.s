# Group: synchronization | TestCase: 01 (TC51)
# Description: Spin_Basic (Basic Spinlock)
# Uses standard amoswap.w for mutual exclusion without inner read loop.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, spin_lock
    la a3, shared_counter
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 50            # Loop 50 times
2:  li t1, 1
    amoswap.w t2, t1, (a2) # Try to acquire lock
    bnez t2, 2b            # If t2!= 0, lock was busy, retry
    
    # Critical section
    lw t3, 0(a3)
    addi t3, t3, 1
    sw t3, 0(a3)
    
    # Release lock
    amoswap.w zero, zero, (a2)
    
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j wait_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 50
2:  li t1, 1
    amoswap.w t2, t1, (a2)
    bnez t2, 2b
    
    # Critical section
    lw t3, 0(a3)
    addi t3, t3, 1
    sw t3, 0(a3)
    
    # Release lock
    amoswap.w zero, zero, (a2)
    
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j wait_end

wait_end:
    csrr t0, mhartid
    bnez t0, pass_end
    
    # Core 0 waits for Core 1 and verifies
1:  lw t1, 4(a1)
    li t2, 2
    bne t1, t2, 1b
    
    lw t3, 0(a3)
    li t4, 100           # 50 + 50 = 100
    bne t3, t4, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
spin_lock:    .word 0
shared_counter:.word 0
sync_flags:   .word 0, 0
system_stacks:.skip 2048
