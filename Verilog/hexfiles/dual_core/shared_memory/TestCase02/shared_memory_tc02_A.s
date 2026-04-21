.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: SHARED_MEMORY
# TESTCASE: 02
# TEST MÔ TẢ: Dual-core Shared Memory full access test - Core A writes all possible edge cases
# Core B polling verify. Test startup skew + visibility + overlapping + signed/zero extension + x0 + unaligned + false sharing
# Trường hợp đặc biệt: 20 sub-test bao gồm normal, negative offset, overlapping byte/half/word, boundary values, bit patterns, chained writes, false sharing potential.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_MEM,  0x00010010

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_MEM
    li   t3, SHARED_FLAG

    # Sub 1: Normal word write
    li   t0, 0x11223344
    sw   t0, 0(t1)

    # Sub 2: Negative offset word
    li   t0, 0x55667788
    sw   t0, -12(t1)

    # Sub 3: Byte write signed
    li   t0, 0x00000080
    sb   t0, 4(t1)

    # Sub 4: Byte write zero extension
    li   t0, 0x000000FF
    sb   t0, 5(t1)

    # Sub 5: Halfword write
    li   t0, 0xABCD
    sh   t0, 8(t1)

    # Sub 6: Overlapping byte after word
    li   t0, 0x55555555
    sw   t0, 12(t1)
    li   t0, 0xAA
    sb   t0, 13(t1)

    # Sub 7: x0 as source
    sw   x0, 20(t1)

    # Sub 8: Large negative offset
    li   t0, 0x80000000
    sw   t0, -24(t1)

    # Sub 9: Unaligned halfword
    li   t0, 0x1234
    sh   t0, 25(t1)

    # Sub 10: All-1s pattern
    li   t0, 0xFFFFFFFF
    sw   t0, 32(t1)

    # Sub 11: All-0s pattern
    sw   x0, 36(t1)

    # Sub 12: 0x55555555 alternating
    li   t0, 0x55555555
    sw   t0, 40(t1)

    # Sub 13: 0xAAAAAAAA alternating
    li   t0, 0xAAAAAAAA
    sw   t0, 44(t1)

    # Sub 14: Signed max
    li   t0, 0x7FFFFFFF
    sw   t0, 48(t1)

    # Sub 15: Signed min +1
    li   t0, 0x80000001
    sw   t0, 52(t1)

    # Sub 16: Chained writes
    li   t0, 0x11223344
    sw   t0, 56(t1)
    li   t0, 0x55667788
    sw   t0, 60(t1)

    # Sub 17: False sharing potential (same cache line)
    li   t0, 0x99AABBCC
    sw   t0, 64(t1)

    # Sub 18: Random mixed pattern
    li   t0, 0x1234ABCD
    sw   t0, 68(t1)

    # Sub 19: Boundary + random
    li   t0, 0x9ABCDEF0
    sw   t0, 72(t1)

    # Sub 20: Deadbeef final
    li   t0, 0xDEADBEEF
    sw   t0, 76(t1)

    li   t2, s0
    sw   t2, 0(t3)                  # set flag cho Core B

    j test_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
fail_loop:
    jal  x0, fail_loop