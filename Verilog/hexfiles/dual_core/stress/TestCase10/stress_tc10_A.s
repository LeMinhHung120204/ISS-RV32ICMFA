.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: STRESS
# TESTCASE: 10
# TEST MÔ TẢ: Dual-core Stress full test - Comprehensive Ultimate Stress (TestCase 10)
# Core A thực hiện heavy loop kết hợp tất cả (memory + atomic + synchronization + false sharing). Test maximum stress.
# Trường hợp đặc biệt: 20 sub-test bao gồm heavy loop, mixed everything, boundary, random pattern, long-running.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_LOCK, 0x00010008
.equ SHARED_SEM,  0x0001000C
.equ SHARED_MEM,  0x00010010

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_MEM
    li   t3, SHARED_FLAG
    li   t6, 2000

heavy_loop:
    # Sub 1-20: Comprehensive stress (kết hợp tất cả)
    li   t0, 0xDEADBEEF ; sw t0, 64(t1)
    li   t0, 0xCAFEBABE ; sw t0, 68(t1)
    li   t0, 0x55555555 ; sw t0, 72(t1)
    li   t0, 0xAAAAAAAA ; sw t0, 76(t1)
    li   t0, 0x11223344 ; sw t0, 80(t1)

    li   t0, 0x11111111 ; amoswap.w t2, t0, (t1)
    li   t0, 0x22222222 ; amoadd.w  t2, t0, (t1)
    li   t0, 0x55555555 ; amoxor.w  t2, t0, (t1)
    li   t0, 0xAAAAAAAA ; amoand.w  t2, t0, (t1)
    li   t0, 0xFFFFFFFF ; amoor.w   t2, t0, (t1)

    li   t0, 1
    amoswap.w t4, t0, (t3)
    sw   x0, 0(t3)
    li   t0, 1
    amoadd.w t4, t0, (SHARED_SEM)
    li   t0, -1
    amoadd.w t4, t0, (SHARED_SEM)

    li   t0, 0x80000001 ; sw t0, 84(t1)
    li   t0, 0x7FFFFFFE ; sw t0, 88(t1)
    li   t0, 0x9ABCDEF0 ; sw t0, 92(t1)
    li   t0, 0x1234ABCD ; sw t0, 96(t1)
    li   t0, 0xCAFEBABE ; sw t0, 100(t1)

    addi t6, t6, -1
    bnez t6, heavy_loop

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