.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: STRESS
# TESTCASE: 02
# TEST MÔ TẢ: Dual-core Stress full test - Heavy Memory + Atomic Contention (TestCase 02)
# Core A thực hiện heavy loop ghi/đọc + atomic contention. Test maximum contention, false sharing, visibility, startup skew, long-running stability.
# Trường hợp đặc biệt: 20 sub-test bao gồm heavy loop, random address, overlapping, signed/unsigned boundary, false sharing, mixed atomic+memory.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_MEM,  0x00010010

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_MEM
    li   t3, SHARED_FLAG
    li   t6, 2000                   # heavy loop counter

heavy_loop:
    # Sub 1-5: Heavy memory write
    li   t0, 0xDEADBEEF ; sw t0, 0(t1)
    li   t0, 0xCAFEBABE ; sw t0, 4(t1)
    li   t0, 0x55555555 ; sw t0, 8(t1)
    li   t0, 0xAAAAAAAA ; sw t0, 12(t1)
    li   t0, 0x11223344 ; sw t0, 16(t1)

    # Sub 6-10: Negative/overlap/unaligned
    li   t0, 0x80000000 ; sw t0, -12(t1)
    li   t0, 0x7FFFFFFF ; sw t0, -8(t1)
    li   t0, 0xAA ; sb t0, -4(t1)
    li   t0, 0x1234 ; sh t0, 25(t1)
    sw   x0, 20(t1)

    # Sub 11-15: False sharing + boundary
    li   t0, 0x99AABBCC ; sw t0, 64(t1)
    li   t0, 0x1234ABCD ; sw t0, 68(t1)
    li   t0, 0x80000001 ; sw t0, 72(t1)
    li   t0, 0x7FFFFFFE ; sw t0, 76(t1)
    li   t0, 0x9ABCDEF0 ; sw t0, 80(t1)

    # Sub 16-20: Mixed atomic + random stress
    li   t0, 0x11111111 ; amoswap.w t2, t0, (t1)
    li   t0, 0x22222222 ; amoadd.w t2, t0, (t1)
    li   t0, 0x55555555 ; amoxor.w t2, t0, (t1)
    li   t0, 0xAAAAAAAA ; amoand.w t2, t0, (t1)
    li   t0, 0xFFFFFFFF ; amoor.w t2, t0, (t1)

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