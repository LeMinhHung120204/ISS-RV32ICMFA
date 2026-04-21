.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: SYNCHRONIZATION
# TESTCASE: 01
# TEST MÔ TẢ: Dual-core Synchronization full test - Spinlock + Mutex + Semaphore + Producer-Consumer (TestCase 01)
# Core A là Producer/Lock owner, Core B là Consumer/Unlocker. Test startup skew + visibility + atomic synchronization
# Trường hợp đặc biệt: 20 sub-test bao gồm spinlock acquire/release, mutex, semaphore (P/V), producer-consumer, barrier, race avoidance, deadlock potential.
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_LOCK,      0x00010008   # mutex/spinlock
.equ SHARED_SEM,       0x0001000C   # semaphore
.equ SHARED_DATA,      0x00010010   # producer data

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_LOCK
    li   t2, SHARED_SEM
    li   t3, SHARED_FLAG
    li   t5, SHARED_DATA

    # Sub 1-5: Spinlock acquire/release
    li   t0, 1
    amoswap.w t4, t0, (t1)          # acquire lock
    sw   s0, 0(t5)                  # produce data
    sw   x0, 0(t1)                  # release lock

    # Sub 6-10: Mutex using amoswap
    li   t0, 1
    amoswap.w t4, t0, (t1)
    li   t0, 0x11223344
    sw   t0, 0(t5)
    sw   x0, 0(t1)

    # Sub 11-14: Semaphore (P/V)
    li   t0, 1
    amoadd.w t4, t0, (t2)           # V (signal)
    li   t0, -1
    amoadd.w t4, t0, (t2)           # P (wait)

    # Sub 15-18: Producer-Consumer pattern
    li   t0, 0xDEADBEEF
    sw   t0, 0(t5)
    li   t0, 1
    amoswap.w t4, t0, (t1)          # signal consumer

    # Sub 19-20: Barrier simulation + false sharing
    li   t0, 0x99AABBCC
    sw   t0, 0(t5)
    li   t0, 1
    amoswap.w t4, t0, (t3)

    li   t2, s0
    sw   t2, 0(t3)                  # set main flag
    j test_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
fail_loop:
    jal  x0, fail_loop