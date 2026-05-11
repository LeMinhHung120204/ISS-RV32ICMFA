# Group: shared_memory | TestCase: 10 (TC70)
# Description: Stale_Read (Fast Read Hazard Detection)
# Verifies that MOESI invalidations propagate before the consumer performs a stale read.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, target_a
    la a3, target_b
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t1, 1
    sw t1, 0(a2)         # Write A = 1
    fence w, w
    sw t1, 0(a3)         # Write B = 1 (Trigger for Core 1)
    
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Spin extremely fast on B
2:  lw t3, 0(a3)
    beqz t3, 2b
    
    # Read A immediately. If MOESI is slow, it might read stale 0 instead of 1.
    fence r, r
    lw t4, 0(a2)
    
    li t5, 1
    bne t4, t5, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_a:  .word 0
target_b:  .word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
