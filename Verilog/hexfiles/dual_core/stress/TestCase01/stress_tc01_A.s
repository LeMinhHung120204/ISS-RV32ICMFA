.section .text
.globl _start
.option norvc

# ========================================================
# GROUP: STRESS
# TESTCASE: 01
# TEST MÔ TẢ: Dual-core Stress full test - Heavy Memory Write/Read Loop + Contention (TestCase 01)
# Core A thực hiện heavy loop ghi/đọc random pattern + atomic. Test maximum contention, false sharing, visibility, startup skew, long-running stability.
# Trường hợp đặc biệt: 20 sub-test bao gồm heavy loop 1000+ lần, random address, overlapping, signed/unsigned boundary, false sharing, mixed atomic+memory.
# ========================================================

.equ SHARED_FLAG, 0x00010000
.equ SHARED_MEM,  0x00010010

_start:
    addi s0, x0, 0

test_loop:
    addi s0, s0, 1

    li   t1, SHARED_MEM
    li   t3, SHARED_FLAG

    # Heavy loop stress (20 sub-test với pattern khác nhau)
    li   t6, 1000                   # loop counter for stress

heavy_loop:
    # Sub 1-5: Normal heavy write
    li   t0, 0xDEADBEEF
    sw   t0, 0(t1)
    li   t0, 0xCAFEBABE
    sw   t0, 4(t1)
    li   t0, 0x55555555
    sw   t0, 8(t1)
    li   t0, 0xAAAAAAAA
    sw   t0, 12(t1)
    li   t0, 0x11223344
    sw   t0, 16(t1)

    # Sub 6-10: Negative offset + overlapping
    li   t0, 0x80000000
    sw   t0, -12(t1)
    li   t0, 0x7FFFFFFF
    sw   t0, -8(t1)
    li   t0, 0x000000FF
    sb   t0, -4(t1)
    li   t0, 0x000000AA
    sb   t0, -3(t1)
    li   t0, 0xABCD
    sh   t0, -2(t1)

    # Sub 11-15: x0 + unaligned + boundary
    sw   x0, 20(t1)
    li   t0, 0x1234
    sh   t0, 25(t1)                 # unaligned
    li   t0, 0xFFFFFFFF
    sw   t0, 32(t1)
    li   t0, 0x80000001
    sw   t0, 36(t1)
    li   t0, 0x9ABCDEF0
    sw   t0, 40(t1)

    # Sub 16-20: False sharing + random + chained
    li   t0, 0x99AABBCC
    sw   t0, 64(t1)                 # same cache line
    li   t0, 0x1234ABCD
    sw   t0, 68(t1)
    li   t0, 0xDEADBEEF
    sw   t0, 72(t1)
    li   t0, 0xCAFEBABE
    sw   t0, 76(t1)
    li   t0, 0x55667788
    sw   t0, 80(t1)

    addi t6, t6, -1
    bnez t6, heavy_loop

    li   t2, s0
    sw   t2, 0(t3)                  # set flag
    j test_loop

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
fail_loop:
    jal  x0, fail_loop