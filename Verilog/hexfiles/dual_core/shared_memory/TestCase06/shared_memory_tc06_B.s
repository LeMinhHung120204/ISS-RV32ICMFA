.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: SHARED_MEMORY
# TESTCASE: 06
# TEST MÔ TẢ: Dual-core Shared Memory full access test - Core B polling + verify all edge cases
# Core B đọc liên tục để bắt visibility dù startup skew.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_MEM,  0x00010010

_start:
    addi s0, x0, 0

poll_loop:
    addi s0, s0, 1

    li   t3, SHARED_FLAG
poll_flag:
    lw   t2, 0(t3)
    beq  t2, x0, poll_flag

    li   t1, SHARED_MEM

    # Verify 20 sub-tests
    lw   t0, 0(t1)
    li   t4, 0xAABBCCDD
    bne  t0, t4, fail

    lw   t0, -12(t1)
    li   t4, 0xEEFF0011
    bne  t0, t4, fail

    lb   t0, 4(t1)
    li   t4, 0xFFFFFF81
    bne  t0, t4, fail

    lbu  t0, 5(t1)
    li   t4, 0x000000FE
    bne  t0, t4, fail

    lh   t0, 8(t1)
    li   t4, 0x0000EF01
    bne  t0, t4, fail

    lw   t0, 12(t1)
    li   t4, 0xAAAAAAAA
    bne  t0, t4, fail

    lb   t0, 13(t1)
    li   t4, 0xFFFFFF55
    bne  t0, t4, fail

    lw   t0, 20(t1)
    li   t4, 0x00000000
    bne  t0, t4, fail

    lw   t0, -24(t1)
    li   t4, 0x7FFFFFFF
    bne  t0, t4, fail

    lh   t0, 25(t1)
    li   t4, 0x00005678
    bne  t0, t4, fail

    lw   t0, 32(t1)
    li   t4, 0xFFFFFFFF
    bne  t0, t4, fail

    lw   t0, 36(t1)
    li   t4, 0x00000000
    bne  t0, t4, fail

    lw   t0, 40(t1)
    li   t4, 0x55555555
    bne  t0, t4, fail

    lw   t0, 44(t1)
    li   t4, 0xAAAAAAAA
    bne  t0, t4, fail

    lw   t0, 48(t1)
    li   t4, 0x7FFFFFFF
    bne  t0, t4, fail

    lw   t0, 52(t1)
    li   t4, 0x80000001
    bne  t0, t4, fail

    lw   t0, 56(t1)
    li   t4, 0xAABBCCDD
    bne  t0, t4, fail

    lw   t0, 60(t1)
    li   t4, 0xEEFF0011
    bne  t0, t4, fail

    lw   t0, 64(t1)
    li   t4, 0x11223344
    bne  t0, t4, fail

    lw   t0, 68(t1)
    li   t4, 0x9ABCDEF0
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