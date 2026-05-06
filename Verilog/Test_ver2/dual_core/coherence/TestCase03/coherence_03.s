# Group: coherence | TestCase: 03 (TC43)
# Description: M_to_O_Trans
# Core 0 modifies data (M). Core 1 reads it. Core 0 -> Owned (O), Core 1 -> Shared (S).
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
    # 1. Core 0 Writes: I -> M
    li t1, 0x33333333
    sw t1, 0(a0)
    
    # Signal Core 1
    li t2, 1; sw t2, 0(a1)
    
    # Wait for Core 1 to read
1:  lw t3, 64(a1); beqz t3, 1b
    j pass_end

core1_main:
    # Wait for Core 0 to write
1:  lw t2, 0(a1); beqz t2, 1b

    # 2. Core 1 Reads: Snoops Core 0. Core 0 M->O. Core 1 I->S.
    # Data is transferred cache-to-cache, bypassing slow memory.
    lw t1, 0(a0)
    
    li t2, 0x33333333
    bne t1, t2, fail
    
    # Signal done
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
