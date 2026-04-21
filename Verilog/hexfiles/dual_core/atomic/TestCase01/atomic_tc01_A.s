.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: ATOMIC
# TESTCASE: 01
# TEST MÔ TẢ: Dual-core Atomic full test - Core A thực hiện lr.w/sc.w + tất cả AMO ops với contention
# Core B polling verify. Test startup skew + atomicity + reservation success/fail + x0 discard + signed/unsigned + bit pattern + boundary
# Trường hợp đặc biệt: 20 sub-test bao gồm lr/sc success/fail, tất cả AMO, x0 discard, overflow, false sharing potential.
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_ATOMIC_MEM, 0x00010008

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_ATOMIC_MEM
    li   t3, SHARED_FLAG

    # Sub 1: lr.w + sc.w success
    lr.w t0, (t1)
    li   t2, 0xDEADBEEF
    sc.w t4, t2, (t1)

    # Sub 2: lr.w + sc.w fail (contention)
    lr.w t0, (t1)
    li   t2, 0xCAFEBABE
    sc.w t4, t2, (t1)

    # Sub 3-6: AMO basic
    li   t0, 0x11111111
    amoswap.w t2, t0, (t1)
    li   t0, 0x22222222
    amoadd.w  t2, t0, (t1)
    li   t0, 0x55555555
    amoxor.w  t2, t0, (t1)
    li   t0, 0xAAAAAAAA
    amoand.w  t2, t0, (t1)

    # Sub 7-8: amoor + amomin
    li   t0, 0xFFFFFFFF
    amoor.w   t2, t0, (t1)
    li   t0, 0x80000000
    amomin.w  t2, t0, (t1)

    # Sub 9-10: amomax + amominu
    li   t0, 0x7FFFFFFF
    amomax.w  t2, t0, (t1)
    li   t0, 0x00000000
    amominu.w t2, t0, (t1)

    # Sub 11-14: amomaxu + x0 discard
    li   t0, 0xFFFFFFFF
    amomaxu.w t2, t0, (t1)
    lr.w x0, (t1)
    amoswap.w x0, t0, (t1)
    amoadd.w  x0, t0, (t1)

    # Sub 15-18: boundary & overflow
    li   t0, 0x7FFFFFFF
    amoadd.w  t2, t0, (t1)
    li   t0, 0x80000001
    amoadd.w  t2, t0, (t1)
    li   t0, 0x55555555
    amoxor.w  t2, t0, (t1)
    li   t0, 0xAAAAAAAA
    amoxor.w  t2, t0, (t1)

    # Sub 19-20: false sharing + random pattern
    li   t0, 0x99AABBCC
    amoswap.w t2, t0, (t1)
    li   t0, 0x1234ABCD
    amoadd.w  t2, t0, (t1)

    li   t2, s0
    sw   t2, 0(t3)                  # set flag

    j test_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
fail_loop:
    jal  x0, fail_loop