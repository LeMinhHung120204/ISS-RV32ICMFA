# Group: synchronization | TestCase: 06 (TC56)
# Description: Fence_WW (Write-to-Write memory ordering)
# Verifies that data in Store Buffer is fully flushed before a flag is written.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, data_flag
    la a3, data_val
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t1, 0xABCDEF00
    sw t1, 0(a3)         # Write data
    
    # Force Store Buffer to flush
    fence w, w
    
    li t1, 1
    sw t1, 0(a2)         # Write flag
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Spin on flag
2:  lw t1, 0(a2)
    beqz t1, 2b
    
    # Read data
    fence r, r
    lw t2, 0(a3)
    li t3, 0xABCDEF00
    bne t2, t3, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
data_flag:.word 0
data_val: .word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
