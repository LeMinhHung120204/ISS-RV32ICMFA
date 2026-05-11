    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Logical group test for RV32I - TEST CASE 06
    # Extra edge cases: chained logical ops + x0
    ####################################################################

    ####################################################################
    # TEST 1-10: chained + x0 + bit patterns
    ####################################################################
    li s0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    lui  t1, 0xaaaa
    li t1, -0x556
    and  t2, t0, t1
    bne  t2, x0, fail

    li s0, 2
    or   t2, t0, t1
    li t3, -1
    bne  t2, t3, fail

    li s0, 3
    xor  t2, t0, t1
    bne  t2, t3, fail

    li s0, 4
    lui  t0, 0x7ffff
    addi t0, t0, -1
    and  t1, t0, x0
    bne  t1, x0, fail

    li s0, 5
    lui  t0, 0x54321
    addi t0, t0, 0x123
    or   t1, t0, x0
    bne  t1, t0, fail

    li s0, 6
    lui  t0, 0x22222
    addi t0, t0, 0x222
    xor  t1, t0, x0
    bne  t1, t0, fail

    li s0, 7
    lui  t0, 0x12345
    and  x0, t0, t0
    bne  x0, x0, fail

    li s0, 8
    lui  t0, 0x13579
    li t0, -0x135
    xor  t1, t0, t0
    bne  t1, x0, fail

    li s0, 9
    lui  t0, 0x12345
    addi t0, t0, 0x678
    xori t1, t0, -1
    lui  t2, 0xedcba
    li t2, -0x679
    bne  t1, t2, fail

    li s0, 10
    lui  t0, 0xf0f0f
    addi t0, t0, 0x0f0
    lui  t1, 0x0ff01
    addi t1, t1, -16
    and  t2, t0, t1
    lui  t3, 0x00f00
    addi t3, t3, 0x0f0
    bne  t2, t3, fail

pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
