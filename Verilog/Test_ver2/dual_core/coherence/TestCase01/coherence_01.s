# Group: coherence | TestCase: 01 (TC41)
# Description: I_to_E_Trans
# Core 0 reads a line from main memory. State transitions from Invalid (I) to Exclusive (E).
.section.text
.global _start
_start:
    csrr t0, mhartid
    
    # Stack allocation
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    bnez t0, park_core

core0_main:
    la a0, target_var
    # Read variable: I -> E transition (Assuming no other core has it)
    lw t1, 0(a0)
    
    # Verify value is 0x11111111 (Init value)
    li t2, 0x11111111
    bne t1, t2, fail

pass_end:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core

.section.data
.align 6
target_var:.word 0x11111111
system_stacks:.skip 2048
