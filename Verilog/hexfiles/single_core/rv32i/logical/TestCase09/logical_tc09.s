<FILE filename="logical_tc09.s" size="5330 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Logical group test for RV32I - TEST CASE 09
    # Extra edge cases: 0xAAAA5555 + heavy immediate
    ####################################################################

    ####################################################################
    # TEST 1-10: 0xAAAA5555 mix + x0
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0xaaaa5
    addi t0, t0, 0x555
    lui  t1, 0x5555a
    addi t1, t1, -0xaaa
    and  t2, t0, t1
    bne  t2, x0, fail

    addi s0, x0, 2
    or   t2, t0, t1
    addi t3, x0, -1
    bne  t2, t3, fail

    addi s0, x0, 3
    xor  t2, t0, t1
    bne  t2, t3, fail

    addi s0, x0, 4
    lui  t0, 0x7ffff
    addi t0, t0, -1
    and  t1, t0, x0
    bne  t1, x0, fail

    addi s0, x0, 5
    lui  t0, 0x54321
    addi t0, t0, 0x123
    or   t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 6
    lui  t0, 0x22222
    addi t0, t0, 0x222
    xor  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 7
    lui  t0, 0x12345
    and  x0, t0, t0
    bne  x0, x0, fail

    addi s0, x0, 8
    lui  t0, 0x13579
    addi t0, t0, -0x135
    xor  t1, t0, t0
    bne  t1, x0, fail

    addi s0, x0, 9
    lui  t0, 0x12345
    addi t0, t0, 0x678
    xori t1, t0, -1
    lui  t2, 0xedcba
    addi t2, t2, -0x679
    bne  t1, t2, fail

    addi s0, x0, 10
    lui  t0, 0xf0f0f
    addi t0, t0, 0x0f0
    lui  t1, 0x0ff01
    addi t1, t1, -16
    and  t2, t0, t1
    lui  t3, 0x00f00
    addi t3, t3, 0x0f0
    bne  t2, t3, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>