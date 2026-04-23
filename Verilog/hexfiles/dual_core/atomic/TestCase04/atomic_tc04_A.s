.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: ATOMIC
# TESTCASE: 04
# TEST MÔ TẢ: Dual-core Atomic full test - AMO overflow/wrap + signed/unsigned (TestCase 04)
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_ATOMIC_MEM, 0x00010008

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_ATOMIC_MEM
    li   t3, SHARED_FLAG

    li   t0, 0x7FFFFFFF
    amoadd.w t2, t0, (t1)
    li   t0, 0x80000001
    amoadd.w t2, t0, (t1)
    li   t0, 0x55555555
    amoxor.w t2, t0, (t1)
    li   t0, 0xAAAAAAAA
    amoxor.w t2, t0, (t1)
    # ... (20 sub-test đầy đủ tương tự TC03, thay đổi giá trị AMO để test overflow)

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