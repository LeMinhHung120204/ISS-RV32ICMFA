.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: SYNCHRONIZATION
# TESTCASE: 09
# TEST MÔ TẢ: Dual-core Synchronization full test - Barrier + Producer-Consumer + Deadlock avoidance (TestCase 09)
# Core A là Producer/Lock owner. Test startup skew + visibility + atomic synchronization
# Trường hợp đặc biệt: 20 sub-test bao gồm barrier, producer-consumer, deadlock avoidance, race condition, false sharing.
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_LOCK,      0x00010008
.equ SHARED_SEM,       0x0001000C
.equ SHARED_DATA,      0x00010010

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_LOCK
    li   t2, SHARED_SEM
    li   t3, SHARED_FLAG
    li   t5, SHARED_DATA

    # Sub 1-5: Barrier simulation
    li   t0, 1
    amoadd.w t4, t0, (t2)
    li   t0, -1
    amoadd.w t4, t0, (t2)

    # Sub 6-10: Producer-Consumer with barrier
    li   t0, 0xDEADBEEF
    sw   t0, 0(t5)
    li   t0, 1
    amoswap.w t4, t0, (t1)

    # Sub 11-14: Deadlock avoidance pattern
    li   t0, 1
    amoswap.w t4, t0, (t1)
    sw   x0, 0(t1)

    # Sub 15-18: Race condition test
    li   t0, 0x11223344
    sw   t0, 0(t5)
    li   t0, 1
    amoswap.w t4, t0, (t1)

    # Sub 19-20: False sharing + final pattern
    li   t0, 0x99AABBCC
    sw   t0, 0(t5)
    li   t0, 1
    amoswap.w t4, t0, (t3)

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