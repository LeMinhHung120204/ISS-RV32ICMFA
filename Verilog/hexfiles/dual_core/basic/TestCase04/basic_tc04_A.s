.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 04
# TEST MÔ TẢ: Basic shared memory visibility - Core A ghi power-of-2 & small positive values
# Kiểm tra startup skew + visibility với power-of-2 patterns.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_DATA, 0x00010004

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_DATA
    li   t3, SHARED_FLAG

    li   t0, 0x00000002
    sw   t0, 0(t1)
    li   t2, 1
    sw   t2, 0(t3)

    li   t0, 0x00000020
    sw   t0, 0(t1)
    li   t2, 2
    sw   t2, 0(t3)

    li   t0, 0x00000200
    sw   t0, 0(t1)
    li   t2, 3
    sw   t2, 0(t3)

    li   t0, 0x00002000
    sw   t0, 0(t1)
    li   t2, 4
    sw   t2, 0(t3)

    li   t0, 0x00020000
    sw   t0, 0(t1)
    li   t2, 5
    sw   t2, 0(t3)

    li   t0, 0x00200000
    sw   t0, 0(t1)
    li   t2, 6
    sw   t2, 0(t3)

    li   t0, 0x02000000
    sw   t0, 0(t1)
    li   t2, 7
    sw   t2, 0(t3)

    li   t0, 0x20000000
    sw   t0, 0(t1)
    li   t2, 8
    sw   t2, 0(t3)

    li   t0, 0x55555555
    sw   t0, 0(t1)
    li   t2, 9
    sw   t2, 0(t3)

    li   t0, 0xAAAAAAAA
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