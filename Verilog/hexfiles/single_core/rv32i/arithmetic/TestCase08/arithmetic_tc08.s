    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 08
    # Extra edge cases: heavy signed negative, x0 in addi/sub
    ####################################################################

    ####################################################################
    # TEST 1-10: signed heavy, x0, auipc
    ####################################################################
    li s0, 1
    li t0, -0x80000000
    addi t1, t0, 0x7fffffff
    addi t2, t1, 1
    bne  t2, x0, fail

    li s0, 2
    li t0, -2048
    addi t1, t0, 2048
    bne  t1, x0, fail

    li s0, 3
    li t0, 0
    addi t1, t0, -2048
    addi t2, t1, 2047
    addi t3, t2, 1
    bne  t3, x0, fail

    li s0, 4
    li t0, -1
    add  t1, t0, t0
    li t2, -2
    bne  t1, t2, fail

    li s0, 5
    auipc t0, 0xfff00
    auipc t1, 0
    lui  t2, 0xfff00
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    li s0, 6
    li t0, 0x55555555
    addi t1, t0, 0xaaaaaaaa
    bne  t1, x0, fail

    li s0, 7
    li t0, 0x7fffffff
    li t1, -0x7fffffff
    bne  t1, x0, fail

    li s0, 8
    li x0, -1234
    bne  x0, x0, fail

    li s0, 9
    lui  t0, 0x80000
    addi t1, t0, -2048
    lui  t2, 0x7ffff
    addi t2, t2, -2048
    bne  t1, t2, fail

    li s0, 10
    li t0, 1
    addi t1, t0, 0x7fffffff
    lui  t2, 0x80000
    bne  t1, t2, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
