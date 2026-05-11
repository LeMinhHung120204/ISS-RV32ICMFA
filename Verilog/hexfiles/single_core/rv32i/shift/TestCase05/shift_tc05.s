    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 05
    # Extra edge cases: 0xFFFF0000 pattern, shift by 32
    ####################################################################

    ####################################################################
    # TEST 1: slli 0xFFFF0000 << 16 = 0x00000000
    ####################################################################
    li s0, 1
    lui  t0, 0xffff0
    slli t1, t0, 16
    bne  t1, x0, fail

    ####################################################################
    # TEST 2-10: srl/sra/srai with 0xFFFF0000
    ####################################################################
    li s0, 2
    lui  t0, 0xffff0
    srli t1, t0, 16
    lui  t2, 0xffff
    bne  t1, t2, fail

    li s0, 3
    lui  t0, 0xffff0
    srai t1, t0, 16
    li t2, -1
    bne  t1, t2, fail

    li s0, 4
    li t0, 0xaaaaaaaa
    slli t1, t0, 0
    bne  t1, t0, fail

    li s0, 5
    li t0, -1
    srli t1, t0, 0
    bne  t1, t0, fail

    li s0, 6
    li t0, 0x80000000
    sra  t1, t0, x0
    bne  t1, t0, fail

    li s0, 7
    li t0, 0x55555555
    slli t1, t0, 0
    bne  t1, t0, fail

    li s0, 8
    li t0, 1
    slli t1, t0, 31
    lui  t2, 0x80000
    bne  t1, t2, fail

    li s0, 9
    li t0, -1
    srli t1, t0, 31
    li t2, 1
    bne  t1, t2, fail

    li s0, 10
    li t0, -8
    srai t1, t0, 2
    li t2, -2
    bne  t1, t2, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
