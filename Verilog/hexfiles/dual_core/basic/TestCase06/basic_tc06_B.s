.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 06
# TEST MÔ TẢ: Basic shared memory visibility - Core B polling flag + verify mixed random 32-bit patterns
# Core A đã ghi, Core B kiểm tra giá trị có đúng không.
# Trường hợp đặc biệt: polling liên tục (handle startup skew), check 10 random bit patterns.
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

    li   t4, 0x11223344
    beq  s0, 1, check
    li   t4, 0xAABBCCDD
    beq  s0, 2, check
    li   t4, 0x99887766
    beq  s0, 3, check
    li   t4, 0x55667788
    beq  s0, 4, check
    li   t4, 0xBBCCDDEE
    beq  s0, 5, check
    li   t4, 0x1122AABB
    beq  s0, 6, check
    li   t4, 0xCCDDEEFF
    beq  s0, 7, check
    li   t4, 0x00112233
    beq  s0, 8, check
    li   t4, 0xFFEECCBB
    beq  s0, 9, check
    li   t4, 0xDEADBEEF
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