    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 09
    # Extra edge cases: auipc heavy + large offset, mixed patterns
    ####################################################################

    ####################################################################
    # TEST 1-10: auipc focus + overflow
    ####################################################################
    li s0, 1
    auipc t0, 0x7ff
    auipc t1, 0
    lui  t2, 0x7ff
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    li s0, 2
    auipc t0, 0x800
    auipc t1, 0
    lui  t2, 0x800
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    li s0, 3
    li t0, 0xaaaaaaaa
    addi t1, t0, 0x55555556
    bne  t1, x0, fail

    li s0, 4
    li t0, 0x7fffffff
    addi t1, t0, 1
    lui  t2, 0x80000
    bne  t1, t2, fail

    li s0, 5
    li t0, -1
    sub  t1, t0, t0
    bne  t1, x0, fail

    li s0, 6
    li x0, 0x12345678
    bne  x0, x0, fail

    li s0, 7
    lui  t0, 0xffff0
    addi t1, t0, 0x1000
    bne  t1, x0, fail

    li s0, 8
    li t0, 2047
    addi t1, t0, -2048
    addi t2, t1, 1
    bne  t2, x0, fail

    li s0, 9
    li t0, 0
    addi t1, t0, 0x7ff
    addi t2, t1, 0x7ff
    lui  t3, 0x1
    addi t3, t3, -2
    bne  t2, t3, fail

    li s0, 10
    lui  t0, 0x80000
    addi t1, t0, 0x7fffffff
    addi t2, t1, 1
    bne  t2, x0, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
