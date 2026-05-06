# Group: coherence | TestCase: 09 (TC49)
# Description: WB_Owned (Eviction of Owned line)
# Core 0 (Owned) forces eviction. Verifies dirty data isn't lost during O-state flush.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    mul t1, t0, 1024
    add sp, sp, t1
    la a0, target_var
    la a1, sync_flags
    la a2, thrash_array
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    # 1. Modify Target
    li t1, 0x99999999
    sw t1, 0(a0)
    li t4, 1; sw t4, 0(a1)   # Signal Core 1 to read
    
1:  lw t5, 64(a1); beqz t5, 1b # Wait for Core 1 to read (M -> O)
    
    # 2. Thrash Cache to force Eviction of Owned line
    li t2, 8192       
2:  sw t2, 0(a2)
    addi a2, a2, 4
    addi t2, t2, -1
    bnez t2, 2b
    
    li t4, 2; sw t4, 0(a1)   # Signal Core 1 to check
    j pass_end

core1_main:
1:  lw t2, 0(a1); beqz t2, 1b

    # Read to force Core 0 into Owned state
    lw t1, 0(a0)
    li t4, 1; sw t4, 64(a1)
    
    # Wait for Core 0 to Evict
2:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 2b
    
    # Read again. Should still be 0x99999999
    lw t1, 0(a0)
    li t2, 0x99999999
    bne t1, t2, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_var:.word 0x0
.align 6
sync_flags:.word 0x0
.align 6
sync_flag_c1:.word 0x0
.align 6
thrash_array:.space 32768
system_stacks:.skip 2048
