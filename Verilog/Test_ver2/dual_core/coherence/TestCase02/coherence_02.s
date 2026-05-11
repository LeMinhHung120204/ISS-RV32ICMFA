# Group: coherence | TestCase: 02 (TC42)
# Description: E_to_M_Trans
# Core 0 reads (I->E) then writes (E->M) to the same cache line. Silent upgrade.
.section.text
.global _start
_start:
    csrr t0, mhartid
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    bnez t0, park_core

core0_main:
    la a0, target_var
    # 1. Read: I -> E
    lw t1, 0(a0)
    
    # 2. Write: E -> M (Silent transition, no bus traffic needed)
    li t2, 0x22222222
    sw t2, 0(a0)
    
    # Verify Write
    lw t3, 0(a0)
    bne t3, t2, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
target_var:.word 0x11111111
system_stacks:.skip 2048
