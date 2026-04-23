.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: ATOMIC
# TESTCASE: 09
# TEST MÔ TẢ: Dual-core Atomic full test - Core A thực hiện mixed AMO + lr/sc (TestCase 09)
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_ATOMIC_MEM, 0x00010008

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_ATOMIC_MEM
    li   t3, SHARED_FLAG

    # Sub 1-10: Mixed lr/sc + AMO
    lr.w t0, (t1)
    li   t2, 0xDEADBEEF
    sc.w t4, t2, (t1)
    amoswap.w t2, t0, (t1)
    amoadd.w  t2, t0, (t1)
    amoxor.w  t2, t0, (t1)
    amoand.w  t2, t0, (t1)
    amoor.w   t2, t0, (t1)
    amomin.w  t2, t0, (t1)
    amomax.w  t2, t0, (t1)

    # Sub 11-20: Unsigned + x0 + boundary + false sharing
    li   t0, 0x00000000
    amominu.w t2, t0, (t1)
    li   t0, 0xFFFFFFFF
    amomaxu.w t2, t0, (t1)
    lr.w x0, (t1)
    amoswap.w x0, t0, (t1)
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