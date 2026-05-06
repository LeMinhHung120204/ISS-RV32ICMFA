# Group: stress | TestCase: 01 (TC81)
# Description: Bus_Storm
# Generates massive amounts of continuous Load/Store requests without ALU delays.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, storm_area
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 500
    # Unrolled load/store storm to saturate the AXI/memory bus
2:  lw t1, 0(a2)
    sw t1, 4(a2)
    lw t2, 8(a2)
    sw t2, 12(a2)
    lw t3, 16(a2)
    sw t3, 20(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 500
2:  lw t1, 32(a2)
    sw t1, 36(a2)
    lw t2, 40(a2)
    sw t2, 44(a2)
    lw t3, 48(a2)
    sw t3, 52(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
storm_area:.space 256
sync_flags:.word 0, 0
system_stacks:.skip 2048
