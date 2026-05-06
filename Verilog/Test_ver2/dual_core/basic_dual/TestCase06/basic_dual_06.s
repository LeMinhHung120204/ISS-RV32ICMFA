# Group: basic_dual | TestCase: 06 (TC26)
# Description: 1-Way Synchronization
# Core 1 spin-waits on a memory flag updated by Core 0.
.section.text
.global _start
_start:
    csrr t0, mhartid
    beqz t0, core0_main

core1_main:
    la a1, sync_flags
1:  lw t2, 0(a1)        # Read flag
    beqz t2, 1b         # Spin if 0
    j pass_end          # Pass when flag becomes 1

core0_main:
    # Do some work
    li t3, 500
2:  addi t3, t3, -1
    bnez t3, 2b
    
    # Set the flag to release Core 1
    la a1, sync_flags
    li t1, 1
    sw t1, 0(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

.section.data
.align 4
sync_flags:.word 0x0
