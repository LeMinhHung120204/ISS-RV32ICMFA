.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: SHARED_MEMORY
# TESTCASE: 09
# TEST MÔ TẢ: Dual-core Shared Memory full access test - Core A writes all possible edge cases (TestCase 09)
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_MEM,  0x00010010

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_MEM
    li   t3, SHARED_FLAG

    li   t0, 0x11223344 ; sw t0, 0(t1)
    li   t0, 0x55667788 ; sw t0, -12(t1)
    li   t0, 0x00000081 ; sb t0, 4(t1)
    li   t0, 0x000000FE ; sb t0, 5(t1)
    li   t0, 0xEF01     ; sh t0, 8(t1)
    li   t0, 0xAAAAAAAA ; sw t0, 12(t1)
    li   t0, 0x55       ; sb t0, 13(t1)
    sw   x0, 20(t1)
    li   t0, 0x7FFFFFFF ; sw t0, -24(t1)
    li   t0, 0x5678     ; sh t0, 25(t1)
    li   t0, 0xFFFFFFFF ; sw t0, 32(t1)
    sw   x0, 36(t1)
    li   t0, 0x55555555 ; sw t0, 40(t1)
    li   t0, 0xAAAAAAAA ; sw t0, 44(t1)
    li   t0, 0x7FFFFFFF ; sw t0, 48(t1)
    li   t0, 0x80000001 ; sw t0, 52(t1)
    li   t0, 0xAABBCCDD ; sw t0, 56(t1)
    li   t0, 0xEEFF0011 ; sw t0, 60(t1)
    li   t0, 0x11223344 ; sw t0, 64(t1)
    li   t0, 0x9ABCDEF0 ; sw t0, 68(t1)
    li   t0, 0x12345678 ; sw t0, 72(t1)
    li   t0, 0xCAFEBABE ; sw t0, 76(t1)

    li   t2, s0
    sw   t2, 0(t3)
    j test_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
fail_loop:
    jal  x0, fail_loop