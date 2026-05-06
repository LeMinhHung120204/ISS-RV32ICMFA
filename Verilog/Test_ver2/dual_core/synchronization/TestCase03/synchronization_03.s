# Group: synchronization | TestCase: 03 (TC53)
# Description: Acq_Flag (Acquire Bit)
# Tests the.aq bit in AMO instructions to enforce load/store ordering.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, aq_lock
    la a3, payload
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    # Set payload
    li t1, 0x12345678
    sw t1, 0(a3)
    
    # Unlock (allow core 1 to proceed)
    sw zero, 0(a2)
    
    li t1, 1; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Wait for lock to be 0 (Acquire semantics)
2:  li t1, 1
    #.aq ensures that the subsequent LOAD to payload does NOT reorder before the AMOSWAP
    amoswap.w.aq t2, t1, (a2)
    bnez t2, 2b
    
    # Critical section
    lw t3, 0(a3)
    li t4, 0x12345678
    bne t3, t4, fail
    
pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
aq_lock:  .word 1       # Locked initially
payload:  .word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
