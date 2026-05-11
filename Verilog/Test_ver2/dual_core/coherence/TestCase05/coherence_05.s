# Group: coherence | TestCase: 05 (TC45)
# Description: S_to_M_Trans (Invalidation)
# Core 0 and 1 hold Shared. Core 1 writes, upgrading S->M and invalidating Core 0.
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
    # Read to establish S state
    lw t1, 0(a0)
    li t2, 1; sw t2, 0(a1)
    
    # Wait for Core 1 to Write
1:  lw t3, 64(a1); beqz t3, 1b
    
    # Core 0's cache line was invalidated! Must fetch from Core 1.
    lw t1, 0(a0)
    li t2, 0x55555555
    bne t1, t2, fail
    j pass_end

core1_main:
    # Wait for Core 0 to read
1:  lw t2, 0(a1); beqz t2, 1b

    # Read to join S state
    lw t1, 0(a0)
    
    # Write to upgrade S->M. Broadcasts Invalidate to Core 0.
    li t2, 0x55555555
    sw t2, 0(a0)
    
    li t2, 1; sw t2, 64(a1)

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_var:.word 0x00000000
.align 6
sync_flags:.word 0x0
.align 6
sync_flag_c1:.word 0x0
system_stacks:.skip 2048
