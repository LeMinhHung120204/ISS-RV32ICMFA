.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: STRESS
# TESTCASE: 08
# TEST MÔ TẢ: Dual-core Stress full test - Mixed Synchronization + Atomic Contention + False Sharing (TestCase 08)
# Core A thực hiện heavy loop ghi/đọc + atomic + synchronization. Test maximum contention, false sharing, visibility, startup skew, long-running stability.
# Trường hợp đặc biệt: 20 sub-test bao gồm heavy loop 2000+ lần, mixed atomic+memory, spinlock/mutex/semaphore, boundary, random pattern, overlapping, x0.
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
    li   t6, 2000                   # heavy loop counter

heavy_loop:
    # Sub 1-5: Mixed memory + false sharing
    li   t0, 0xDEADBEEF ; sw t0, 64(t1)
    li   t0, 0xCAFEBABE ; sw t0, 68(t1)
    li   t0, 0x55555555 ; sw t0, 72(t1)
    li   t0, 0xAAAAAAAA ; sw t0, 76(t1)
    li   t0, 0x11223344 ; sw t0, 80(t1)

    # Sub 6-10: Atomic contention
    li   t0, 0x11111111 ; amoswap.w t2, t0, (t1)
    li   t0, 0x22222222 ; amoadd.w  t2, t0, (t1)
    li   t0, 0x55555555 ; amoxor.w  t2, t0, (t1)
    li   t0, 0xAAAAAAAA ; amoand.w  t2, t0, (t1)
    li   t0, 0xFFFFFFFF ; amoor.w   t2, t0, (t1)

    # Sub 11-15: Synchronization (spinlock/mutex/semaphore)
    li   t0, 1
    amoswap.w t4, t0, (t3)          # spinlock
    sw   x0, 0(t3)
    li   t0, 1
    amoadd.w t4, t0, (SHARED_SEM)
    li   t0, -1
    amoadd.w t4, t0, (SHARED_SEM)

    # Sub 16-20: Boundary + random + chained stress
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