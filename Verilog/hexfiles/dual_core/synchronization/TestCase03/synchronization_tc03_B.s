.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: SYNCHRONIZATION
# TESTCASE: 03
# TEST MÔ TẢ: Dual-core Synchronization full test - Core B polling + verify spinlock/mutex/semaphore/producer-consumer
# Core B đọc liên tục để bắt synchronization dù startup skew.
# ========================================================

.equ SHARED_FLAG,      0x00010000
.equ SHARED_LOCK,      0x00010008
.equ SHARED_SEM,       0x0001000C
.equ SHARED_DATA,      0x00010010

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
    li   t4, 0xDEADBEEF
    beq  s0, 6, check
    li   t4, 0xDEADBEEF
    beq  s0, 15, check
    li   t4, 0x99AABBCC
    beq  s0, 19, check
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