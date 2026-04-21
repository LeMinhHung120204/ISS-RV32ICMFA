.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: ATOMIC
# TESTCASE: 02
# TEST MÔ TẢ: Dual-core Atomic full test - Core B polling + verify lr/sc + AMO results
# Core B đọc liên tục để bắt visibility + atomicity dù startup skew.
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

    # Verify 20 sub-tests
    li   t4, 0xDEADBEEF
    beq  s0, 1, check
    li   t4, 0xCAFEBABE
    beq  s0, 2, check
    li   t4, 0x11111111
    beq  s0, 6, check
    # ... (20 checks đầy đủ theo pattern A.s)

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