# Group: stress | TestCase: 07 (TC87)
# Description: Store_Buf_Full
# Blasts back-to-back STORE instructions to overflow the write buffers.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a2, store_array
    bnez t0, park_core

core0_main:
    li t0, 0xDEADBEEF
    # 32 back-to-back stores (Most CPUs have 4-8 entry store buffers)
    sw t0, 0(a2); sw t0, 4(a2); sw t0, 8(a2); sw t0, 12(a2)
    sw t0, 16(a2); sw t0, 20(a2); sw t0, 24(a2); sw t0, 28(a2)
    sw t0, 32(a2); sw t0, 36(a2); sw t0, 40(a2); sw t0, 44(a2)
    sw t0, 48(a2); sw t0, 52(a2); sw t0, 56(a2); sw t0, 60(a2)
    sw t0, 64(a2); sw t0, 68(a2); sw t0, 72(a2); sw t0, 76(a2)
    sw t0, 80(a2); sw t0, 84(a2); sw t0, 88(a2); sw t0, 92(a2)
    sw t0, 96(a2); sw t0, 100(a2); sw t0, 104(a2); sw t0, 108(a2)
    sw t0, 112(a2); sw t0, 116(a2); sw t0, 120(a2); sw t0, 124(a2)
    
    # Read back to ensure data integrity
    lw t1, 124(a2)
    bne t0, t1, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
store_array:.space 256
system_stacks:.skip 2048
