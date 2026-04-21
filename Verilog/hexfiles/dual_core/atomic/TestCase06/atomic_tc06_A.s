.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: ATOMIC
# TESTCASE: 06
# TEST MÔ TẢ: Dual-core Atomic full test - Core A thực hiện signed min/max + overflow (TestCase 06)
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_ATOMIC_MEM, 0x00010008

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_ATOMIC_MEM
    li   t3, SHARED_FLAG

    li   t0, 0x80000000
    amomin.w t2, t0, (t1)
    li   t0, 0x7FFFFFFF
    amomax.w t2, t0, (t1)
    li   t0, 0x80000001
    amoadd.w t2, t0, (t1)
    li   t0, 0x7FFFFFFE
    amoadd.w t2, t0, (t1)
    # ... (20 sub-test signed min/max + overflow pattern)

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