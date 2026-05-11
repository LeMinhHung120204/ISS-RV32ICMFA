# Group: stress | TestCase: 04 (TC84)
# Description: Inval_Storm
# Forces continuous snoops and MOESI Invalidations across the bus.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, inval_target
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 1000
    li t1, 0x1111
2:  lw t3, 0(a2)         # Force Shared/Owned
    sw t1, 0(a2)         # Force Modified (Invalidates Core 1)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 1000
    li t1, 0x2222
2:  sw t1, 0(a2)         # Force Modified (Invalidates Core 0)
    lw t3, 0(a2)         # Force Exclusive/Shared
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
inval_target:.word 0
sync_flags: .word 0, 0
system_stacks:.skip 2048
