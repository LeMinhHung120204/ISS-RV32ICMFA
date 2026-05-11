# Group: producer_consumer | TestCase: 01 (TC71)
# Description: SPSC_Locked (Single-Producer Single-Consumer with Spinlock)
# Verifies a shared ring buffer strictly protected by an atomic spinlock.
.section.text
.global _start
_start:
    csrr t0, mhartid
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    la a1, sync_flags
    la a2, q_lock
    la a3, q_data
    
    beqz t0, producer_core
    li t1, 1
    beq t0, t1, consumer_core
    j park_core

producer_core:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Acquire Lock
2:  li t1, 1
    amoswap.w.aq t2, t1, (a2)
    bnez t2, 2b

    # Critical Section: Write Data
    li t1, 0x11223344
    sw t1, 0(a3)
    
    # Release Lock
    amoswap.w.rl zero, zero, (a2)
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

consumer_core:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Wait for Producer to finish (sync flag = 2)
1:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 1b

    # Acquire Lock
2:  li t1, 1
    amoswap.w.aq t2, t1, (a2)
    bnez t2, 2b

    # Critical Section: Read Data
    lw t1, 0(a3)
    
    # Release Lock
    amoswap.w.rl zero, zero, (a2)
    
    li t2, 0x11223344
    bne t1, t2, fail
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
q_lock:      .word 0x0
q_data:      .word 0x0
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
