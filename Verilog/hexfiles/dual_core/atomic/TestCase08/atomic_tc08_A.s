.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: ATOMIC
# TESTCASE: 08
# TEST MÔ TẢ: Dual-core Atomic full test - Core A thực hiện x0 discard + lr/sc heavy (TestCase 08)
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_ATOMIC_MEM, 0x00010008

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_ATOMIC_MEM
    li   t3, SHARED_FLAG

    # Sub 1-8: x0 discard + lr/sc
    lr.w x0, (t1)
    li   t2, 0xDEADBEEF
    sc.w x0, t2, (t1)
    lr.w x0, (t1)
    li   t2, 0xCAFEBABE
    sc.w x0, t2, (t1)
    amoswap.w x0, t2, (t1)
    amoadd.w  x0, t2, (t1)
    amoxor.w  x0, t2, (t1)
    amoand.w  x0, t2, (t1)

    # Sub 9-14: AMO normal + boundary
    li   t0, 0xFFFFFFFF
    amoor.w   t2, t0, (t1)
    li   t0, 0x80000000
    amomin.w  t2, t0, (t1)
    li   t0, 0x7FFFFFFF
    amomax.w  t2, t0, (t1)
    li   t0, 0x00000000
    amominu.w t2, t0, (t1)
    li   t0, 0xFFFFFFFF
    amomaxu.w t2, t0, (t1)

    # Sub 15-20: Contention + false sharing + random
    li   t0, 0x80000001
    amoadd.w  t2, t0, (t1)
    li   t0, 0x99AABBCC
    amoswap.w t2, t0, (t1)
    li   t0, 0x1234ABCD
    amoadd.w  t2, t0, (t1)
    li   t0, 0x9ABCDEF0
    amoxor.w  t2, t0, (t1)
    li   t0, 0xCAFEBABE
    amoswap.w t2, t0, (t1)
    li   t0, 0xDEADBEEF
    amoadd.w  t2, t0, (t1)

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