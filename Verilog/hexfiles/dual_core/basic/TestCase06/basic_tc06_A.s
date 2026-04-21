.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 06
# TEST MÔ TẢ: Basic shared memory visibility - Core A ghi mixed random 32-bit patterns
# Kiểm tra startup skew + visibility với random bit patterns.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_DATA, 0x00010004

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_DATA
    li   t3, SHARED_FLAG

    li   t0, 0x11223344
    sw   t0, 0(t1)
    li   t2, 1
    sw   t2, 0(t3)

    li   t0, 0xAABBCCDD
    sw   t0, 0(t1)
    li   t2, 2
    sw   t2, 0(t3)

    li   t0, 0x99887766
    sw   t0, 0(t1)
    li   t2, 3
    sw   t2, 0(t3)

    li   t0, 0x55667788
    sw   t0, 0(t1)
    li   t2, 4
    sw   t2, 0(t3)

    li   t0, 0xBBCCDDEE
    sw   t0, 0(t1)
    li   t2, 5
    sw   t2, 0(t3)

    li   t0, 0x1122AABB
    sw   t0, 0(t1)
    li   t2, 6
    sw   t2, 0(t3)

    li   t0, 0xCCDDEEFF
    sw   t0, 0(t1)
    li   t2, 7
    sw   t2, 0(t3)

    li   t0, 0x00112233
    sw   t0, 0(t1)
    li   t2, 8
    sw   t2, 0(t3)

    li   t0, 0xFFEECCBB
    sw   t0, 0(t1)
    li   t2, 9
    sw   t2, 0(t3)

    li   t0, 0xDEADBEEF
    sw   t0, 0(t1)
    li   t2, 10
    sw   t2, 0(t3)

    j test_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
fail_loop:
    jal  x0, fail_loop