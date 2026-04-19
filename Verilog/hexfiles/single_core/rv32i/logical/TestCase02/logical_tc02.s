<FILE filename="logical_tc02.s" size="5210 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Logical group test for RV32I - TEST CASE 02
    # Extra edge cases: 0x55555555 / 0xAAAAAAAA patterns, chained ops
    ####################################################################

    ####################################################################
    # TEST 1: and 0x55555555 & 0xAAAAAAAA = 0
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    lui  t1, 0xaaaa a
    addi t1, t1, -0x556
    and  t2, t0, t1
    bne  t2, x0, fail

    ####################################################################
    # TEST 2: or 0x55555555 | 0xAAAAAAAA = 0xFFFFFFFF
    ####################################################################
    addi s0, x0, 2
    or   t2, t0, t1
    addi t3, x0, -1
    bne  t2, t3, fail

    ####################################################################
    # TEST 3: xor 0x55555555 ^ 0xAAAAAAAA = 0xFFFFFFFF
    ####################################################################
    addi s0, x0, 3
    xor  t2, t0, t1
    bne  t2, t3, fail

    ####################################################################
    # TEST 4: andi with max immediate
    ####################################################################
    addi s0, x0, 4
    lui  t0, 0x12345
    addi t0, t0, 0x678
    andi t1, t0, 0x7ff
    lui  t2, 0x0
    addi t2, t2, 0x678
    bne  t1, t2, fail

    ####################################################################
    # TEST 5-10: x0 behavior, negative, chained
    ####################################################################
    addi s0, x0, 5
    lui  t0, 0x7ffff
    addi t0, t0, -1
    and  t1, t0, x0
    bne  t1, x0, fail

    addi s0, x0, 6
    lui  t0, 0x54321
    addi t0, t0, 0x123
    or   t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 7
    lui  t0, 0x22222
    addi t0, t0, 0x222
    xor  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 8
    lui  t0, 0x12345
    and  x0, t0, t0
    bne  x0, x0, fail

    addi s0, x0, 9
    lui  t0, 0x13579
    addi t0, t0, -0x135
    xor  t1, t0, t0
    bne  t1, x0, fail

    addi s0, x0, 10
    lui  t0, 0x12345
    addi t0, t0, 0x678
    xori t1, t0, -1
    lui  t2, 0xedcba
    addi t2, t2, -0x679
    bne  t1, t2, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>