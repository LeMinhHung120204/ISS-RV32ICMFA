.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 02
# TEST MÔ TẢ: Basic shared memory visibility - Core A ghi small positive & power-of-2 patterns
# Core B polling verify. Kiểm tra startup skew + visibility với các giá trị nhỏ và power-of-2.
# Trường hợp đặc biệt: 10 sub-test với power-of-2 + bit pattern.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_DATA, 0x00010004

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_DATA
    li   t3, SHARED_FLAG

    # Sub-test 1
    li   t0, 0x00000001
    sw   t0, 0(t1)
    li   t2, 1
    sw   t2, 0(t3)

    # Sub-test 2
    li   t0, 0x00000010
    sw   t0, 0(t1)
    li   t2, 2
    sw   t2, 0(t3)

    # Sub-test 3
    li   t0, 0x00000100
    sw   t0, 0(t1)
    li   t2, 3
    sw   t2, 0(t3)

    # Sub-test 4
    li   t0, 0x00001000
    sw   t0, 0(t1)
    li   t2, 4
    sw   t2, 0(t3)

    # Sub-test 5
    li   t0, 0x00010000
    sw   t0, 0(t1)
    li   t2, 5
    sw   t2, 0(t3)

    # Sub-test 6
    li   t0, 0x00100000
    sw   t0, 0(t1)
    li   t2, 6
    sw   t2, 0(t3)

    # Sub-test 7
    li   t0, 0x01000000
    sw   t0, 0(t1)
    li   t2, 7
    sw   t2, 0(t3)

    # Sub-test 8
    li   t0, 0x10000000
    sw   t0, 0(t1)
    li   t2, 8
    sw   t2, 0(t3)

    # Sub-test 9
    li   t0, 0x55555555
    sw   t0, 0(t1)
    li   t2, 9
    sw   t2, 0(t3)

    # Sub-test 10
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