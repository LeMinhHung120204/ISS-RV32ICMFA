.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 01
# TEST MÔ TẢ: Basic shared memory visibility - Core A ghi magic values + set flag
# Core B polling verify. Kiểm tra startup skew + memory visibility đơn giản
# Trường hợp đặc biệt: 10 sub-test với magic numbers khác nhau (DEADBEEF, CAFEBABE...)
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_DATA, 0x00010004

_start:
    addi s0, x0, 0                  # s0 = sub-test ID

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_DATA            # data address
    li   t3, SHARED_FLAG            # flag address

    # Sub-test 1: Magic 0xDEADBEEF
    li   t0, 0xDEADBEEF
    sw   t0, 0(t1)
    li   t2, 1
    sw   t2, 0(t3)

    # Sub-test 2: Magic 0xCAFEBABE
    li   t0, 0xCAFEBABE
    sw   t0, 0(t1)
    li   t2, 2
    sw   t2, 0(t3)

    # Sub-test 3: Magic 0x12345678
    li   t0, 0x12345678
    sw   t0, 0(t1)
    li   t2, 3
    sw   t2, 0(t3)

    # Sub-test 4: Magic 0x55555555
    li   t0, 0x55555555
    sw   t0, 0(t1)
    li   t2, 4
    sw   t2, 0(t3)

    # Sub-test 5: Magic 0xAAAAAAAA
    li   t0, 0xAAAAAAAA
    sw   t0, 0(t1)
    li   t2, 5
    sw   t2, 0(t3)

    # Sub-test 6: Magic 0xFFFFFFFF (all 1)
    li   t0, 0xFFFFFFFF
    sw   t0, 0(t1)
    li   t2, 6
    sw   t2, 0(t3)

    # Sub-test 7: Magic 0x00000000 (zero)
    li   t0, 0x00000000
    sw   t0, 0(t1)
    li   t2, 7
    sw   t2, 0(t3)

    # Sub-test 8: Magic 0x80000000 (MSB set)
    li   t0, 0x80000000
    sw   t0, 0(t1)
    li   t2, 8
    sw   t2, 0(t3)

    # Sub-test 9: Magic 0x7FFFFFFF (max signed)
    li   t0, 0x7FFFFFFF
    sw   t0, 0(t1)
    li   t2, 9
    sw   t2, 0(t3)

    # Sub-test 10: Magic 0x1234ABCD (random pattern)
    li   t0, 0x1234ABCD
    sw   t0, 0(t1)
    li   t2, 10
    sw   t2, 0(t3)

    j test_loop                     # tiếp tục loop sub-test

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
fail_loop:
    jal  x0, fail_loop