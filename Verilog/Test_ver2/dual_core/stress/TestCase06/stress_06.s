# Group: stress | TestCase: 06 (TC86)
# Description: Stall_Max
# Interleaves Load and ALU operations to enforce maximum Load-Use stalls.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a2, stall_data
    bnez t0, park_core

core0_main:
    li t0, 100
2:  
    # Load-Use Hazard Storm
    lw t1, 0(a2)
    addi t1, t1, 1       # STALL
    sw t1, 0(a2)
    
    lw t2, 4(a2)
    addi t2, t2, 1       # STALL
    sw t2, 4(a2)
    
    lw t3, 8(a2)
    addi t3, t3, 1       # STALL
    sw t3, 8(a2)
    
    addi t0, t0, -1
    bnez t0, 2b

    # Verify
    lw t1, 0(a2)
    li t2, 100
    bne t1, t2, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
stall_data:.word 0, 0, 0, 0
system_stacks:.skip 2048
