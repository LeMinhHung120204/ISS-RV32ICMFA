# Group: stress | TestCase: 09 (TC89)
# Description: Live_Lock
# Cores fight continuously using LR/SC, starving each other. 
# Breaks after timeout to avoid hanging the simulator.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, lock_val
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 500           # Timeout counter
livelock_loop0:
    lr.w t1, (a2)
    # Give Core 1 time to invalidate
    nop; nop; nop
    sc.w t3, t1, (a2)
    beqz t3, 2f          # Success!
    
    # Failed. Decrease timeout
    addi t0, t0, -1
    bnez t0, livelock_loop0
    
2:  li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 500
livelock_loop1:
    lr.w t1, (a2)
    nop; nop; nop
    sc.w t3, t1, (a2)
    beqz t3, 2f          
    
    addi t0, t0, -1
    bnez t0, livelock_loop1
    
2:  li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
lock_val:  .word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
