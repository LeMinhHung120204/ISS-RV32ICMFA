.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: ATOMIC
# TESTCASE: 06
# TEST MÔ TẢ: Dual-core Atomic full test - Core B polling + verify signed min/max + overflow (TestCase 06)
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_ATOMIC_MEM, 0x00010008

_start:
    addi s0, x0, 0

poll_loop:
    addi s0, s0, 1

    li   t3, SHARED_FLAG
poll_flag:
    lw   t2, 0(t3)
    beq  t2, x0, poll_flag

    li   t1, SHARED_ATOMIC_MEM
    lw   t0, 0(t1)

    li   t4, 0x80000000
    beq  s0, 1, check
    li   t4, 0x7FFFFFFF
    beq  s0, 2, check
    li   t4, 0x80000000
    beq  s0, 3, check
    li   t4, 0x7FFFFFFF
    beq  s0, 4, check
    li   t4, 0x55555555
    beq  s0, 5, check
    li   t4, 0xAAAAAAAA
    beq  s0, 6, check
    li   t4, 0x12345678
    beq  s0, 7, check
    li   t4, 0x9ABCDEF0
    beq  s0, 8, check
    li   t4, 0xDEADBEEF
    beq  s0, 9, check
    li   t4, 0xCAFEBABE
    beq  s0, 10, check
    li   t4, 0x80000001
    beq  s0, 11, check
    li   t4, 0x7FFFFFFE
    beq  s0, 12, check
    # ... (các sub-test 13-20 tương tự pattern signed/overflow)

check:
    bne  t0, t4, fail
    sw   x0, 0(t3)
    j poll_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    addi a0, s0, 0
fail_loop:
    jal  x0, fail_loop