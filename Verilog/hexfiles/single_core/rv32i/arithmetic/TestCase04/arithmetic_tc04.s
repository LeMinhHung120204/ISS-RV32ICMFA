    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 04
    # Extra edge cases: 0xFFFF0000 pattern, large positive/negative mix
    ####################################################################

    ####################################################################
    # TEST 1: add 0xFFFF0000 + 0x00010000 = 0x00000000
    ####################################################################
    li s0, 1
    lui  t0, 0xffff0
    lui  t1, 0x1
    add  t2, t0, t1
    bne  t2, x0, fail

    ####################################################################
    # TEST 2: sub 0x80000000 - 0x7fffffff = 1
    ####################################################################
    li s0, 2
    lui  t0, 0x80000
    lui  t1, 0x7ffff
    addi t1, t1, -1
    sub  t2, t0, t1
    li t3, 1
    bne  t2, t3, fail

    ####################################################################
    # TEST 3-10: chained ops, x0, auipc large offset, etc.
    ####################################################################
    li s0, 3
    lui  t0, 0x80000     # t0 = 0x80000000
    addi t0, t0, -1      # t0 = 0x7fffffff (Cách nạp số max 32-bit chuẩn)
    addi t1, t0, 1       # t1 = 0x80000000 (Phép tính này OK vì 1 < 2047)

    li s0, 4
    li t0, 0
    addi t1, t0, -1
    addi t2, t1, -1
    li t3, -2
    bne  t2, t3, fail

    # TEST 5:
    li s0, 5
    # Tạo số 0x5555:
    lui  t0, 0x5         # 0x00005000
    addi t0, t0, 0x555   # 0x00005555 (0x555 = 1365, vẫn < 2047 nên OK)
    # Cộng t0 với chính nó:
    add  t1, t0, t0      # t1 = 0xAAAAA (Sử dụng add thay vì addi số lớn)
    lui  t2, 0xaaaaa     # Xóa dấu cách ở đây

    # TEST 6:
    li s0, 6
    li x0, 2047    # 0x1234 quá lớn, dùng 2047 là số lớn nhất cho phép
    bne  x0, x0, fail

    li s0, 7
    auipc t0, 0x10
    auipc t1, 0
    lui  t2, 0x10
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    li s0, 8
    auipc t0, 0xfffe0
    auipc t1, 0
    lui  t2, 0xfffe0
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    li s0, 9
    li t0, 0
    addi t1, t0, 2047
    addi t2, t1, 2047
    lui  t3, 0x1
    addi t3, t3, -2
    bne  t2, t3, fail

    li s0, 10
    lui  t0, 0x80000
    addi t0, t0, -1
    addi t1, t0, 2
    lui  t2, 0x80000
    addi t2, t2, 1
    bne  t1, t2, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
