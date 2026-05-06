# Group: stress | TestCase: 03 (TC83)
# Description: Atomic_Storm
# Blasts the memory controller with thousands of AMOADD instructions.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, atom_target
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 200
    li t1, 1
    # Unrolled AMO storm
2:  amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 200
    li t1, 1
2:  amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    amoadd.w zero, t1, 0(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    # Wait for Core 0
3:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 3b
    
    # Check result: 200 * 5 * 2 = 2000
    lw t4, 0(a2)
    li t5, 2000
    bne t4, t5, fail
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
atom_target:.word 0
sync_flags: .word 0, 0
system_stacks:.skip 2048
