# Group: synchronization | TestCase: 04 (TC54)
# Description: Rel_Flag (Release Bit)
# Tests the.rl bit in AMO instructions to ensure prior stores are visible.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, rl_lock
    la a3, payload
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Critical section modifications
    li t1, 0x87654321
    sw t1, 0(a3)
    
    #.rl ensures the payload store is flushed before the lock is released
    amoswap.w.rl zero, zero, (a2)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Poll for lock release
2:  lw t1, 0(a2)
    bnez t1, 2b
    
    # Since.rl was used by Core 0, payload MUST be up-to-date here
    fence r, r
    lw t2, 0(a3)
    li t3, 0x87654321
    bne t2, t3, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
rl_lock:  .word 1       # Locked initially
payload:  .word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
