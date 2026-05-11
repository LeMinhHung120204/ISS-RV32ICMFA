# Group: coherence | TestCase: 06 (TC46)
# Description: O_to_I_Trans
# Core 0 (Owned) is invalidated when Core 1 (Shared) writes to the block.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    mul t1, t0, 1024
    add sp, sp, t1
    la a0, target_var
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    # Write to establish M state
    li t1, 0x66666666
    sw t1, 0(a0)
    li t2, 1; sw t2, 0(a1)
    
    # Wait for Core 1 to Read and Write
1:  lw t3, 64(a1); beqz t3, 1b
    
    # Core 0 was in Owned, but Core 1 wrote, so Core 0 is now Invalid.
    lw t1, 0(a0)
    li t2, 0x77777777
    bne t1, t2, fail
    j pass_end

core1_main:
    # Wait for Core 0 M state
1:  lw t2, 0(a1); beqz t2, 1b

    # Read to force Core 0 to Owned, Core 1 to Shared
    lw t1, 0(a0)
    
    # Write to upgrade S->M. Forces Core 0's Owned state to Invalid!
    li t2, 0x77777777
    sw t2, 0(a0)
    
    li t2, 1; sw t2, 64(a1)

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
system_stacks:.skip 2048
