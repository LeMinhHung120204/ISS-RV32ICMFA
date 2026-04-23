.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: BASIC
# TESTCASE: 10
# TEST MÔ TẢ: Basic shared memory visibility - Core B polling flag + verify comprehensive patterns
# Trường hợp đặc biệt: polling liên tục, check tất cả pattern stress.
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

    li   t4, 0xDEADBEEF
    beq  s0, 1, check
    li   t4, 0xCAFEBABE
    beq  s0, 2, check
    li   t4, 0x55555555
    beq  s0, 3, check
    li   t4, 0xAAAAAAAA
    beq  s0, 4, check
    li   t4, 0x80000000
    beq  s0, 5, check
    li   t4, 0x7FFFFFFF
    beq  s0, 6, check
    li   t4, 0x00000000
    beq  s0, 7, check
    li   t4, 0xFFFFFFFF
    beq  s0, 8, check
    li   t4, 0x1234ABCD
    beq  s0, 9, check
    li   t4, 0x9ABCDEF0
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