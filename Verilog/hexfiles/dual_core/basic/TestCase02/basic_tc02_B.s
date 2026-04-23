.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 02
# TEST MÔ TẢ: Basic shared memory visibility - Core B polling flag + verify power-of-2 patterns
# Core A đã ghi, Core B kiểm tra giá trị có đúng không.
# Trường hợp đặc biệt: polling liên tục (handle startup skew), check 10 power-of-2 & bit pattern.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_DATA, 0x00010004

_start:
    addi s0, x0, 0

poll_loop:
    addi s0, s0, 1

    li   t3, SHARED_FLAG
poll_flag:
    lw   t2, 0(t3)
    beq  t2, x0, poll_flag

    li   t1, SHARED_DATA
    lw   t0, 0(t1)

    li   t4, 0x00000001
    beq  s0, 1, check
    li   t4, 0x00000010
    beq  s0, 2, check
    li   t4, 0x00000100
    beq  s0, 3, check
    li   t4, 0x00001000
    beq  s0, 4, check
    li   t4, 0x00010000
    beq  s0, 5, check
    li   t4, 0x00100000
    beq  s0, 6, check
    li   t4, 0x01000000
    beq  s0, 7, check
    li   t4, 0x10000000
    beq  s0, 8, check
    li   t4, 0x55555555
    beq  s0, 9, check
    li   t4, 0xAAAAAAAA
    beq  s0, 10, check

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