    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 06
    # Extra edge cases: x0 strict in every shift, chained shifts
    ####################################################################

    ####################################################################
    # TEST 1-10: x0 heavy + chained shift
    ####################################################################
    li s0, 1
    li t0, 1
    sll  t1, t0, x0
    bne  t1, t0, fail

    li s0, 2
    li t0, 0x80000000
    sra  t1, t0, x0
    bne  t1, t0, fail

    li s0, 3
    li t0, 0xaaaaaaaa
    slli t1, t0, 0
    bne  t1, t0, fail

    li s0, 4
    li t0, -1
    srli t1, t0, 0
    bne  t1, t0, fail

    li s0, 5
    li t0, -5
    srai t1, t0, 0
    bne  t1, t0, fail

    li s0, 6
    li t0, 1
    slli t1, t0, 31
    lui  t2, 0x80000
    bne  t1, t2, fail

    li s0, 7
    li t0, 0x7fffffff
    srli t1, t0, 31
    li t2, 0
    bne  t1, t2, fail

    li s0, 8
    li t0, 0x80000000
    srai t1, t0, 31
    li t2, -1
    bne  t1, t2, fail

    li s0, 9
    li t0, 0x55555555
    sll  t1, t0, x0
    bne  t1, t0, fail

    li s0, 10
    li t0, 0xaaaaaaaa
    srl  t1, t0, x0
    bne  t1, t0, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
