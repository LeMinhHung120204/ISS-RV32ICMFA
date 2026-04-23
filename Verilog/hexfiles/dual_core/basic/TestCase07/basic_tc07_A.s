.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 07
# TEST MÔ TẢ: Basic shared memory visibility - Core A ghi 0x5555AAAA alternating bit patterns
# Kiểm tra startup skew + visibility với alternating bit patterns.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_DATA, 0x00010004

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_DATA
    li   t3, SHARED_FLAG

    li   t0, 0x55555555
    sw   t0, 0(t1)
    li   t2, 1
    sw   t2, 0(t3)

    li   t0, 0xAAAAAAAA
    sw   t0, 0(t1)
    li   t2, 2
    sw   t2, 0(t3)

    li   t0, 0x5555AAAA
    sw   t0, 0(t1)
    li   t2, 3
    sw   t2, 0(t3)

    li   t0, 0xAAAA5555
    sw   t0, 0(t1)
    li   t2, 4
    sw   t2, 0(t3)

    li   t0, 0x555AAAAA
    sw   t0, 0(t1)
    li   t2, 5
    sw   t2, 0(t3)

    li   t0, 0xAAA55555
    sw   t0, 0(t1)
    li   t2, 6
    sw   t2, 0(t3)

    li   t0, 0x555555AA
    sw   t0, 0(t1)
    li   t2, 7
    sw   t2, 0(t3)

    li   t0, 0xAAAA5555
    sw   t0, 0(t1)
    li   t2, 8
    sw   t2, 0(t3)

    li   t0, 0x5555AAAA
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