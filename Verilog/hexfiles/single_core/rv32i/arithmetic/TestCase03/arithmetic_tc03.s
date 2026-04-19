<FILE filename="arithmetic_tc03.s" size="5480 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 03
    # Extra edge cases: 0xAAAAAAAA pattern, chained add/sub, signed max
    ####################################################################

    ####################################################################
    # TEST 1: add 0xAAAAAAAA + 0x55555555 = 0xFFFFFFFF
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0xaaaa a
    addi t0, t0, -0x556
    lui  t1, 0x55555
    addi t1, t1, 0x555
    add  t2, t0, t1
    addi t3, x0, -1
    bne  t2, t3, fail

    ####################################################################
    # TEST 2: sub 0xAAAAAAAA - 0x55555555 = 0x55555555
    ####################################################################
    addi s0, x0, 2
    sub  t2, t0, t1
    bne  t2, t1, fail

    ####################################################################
    # TEST 3: addi 0x7fff + 0x7fff = 0xfffe (overflow)
    ####################################################################
    addi s0, x0, 3
    addi t0, x0, 0x7fff
    addi t1, t0, 0x7fff
    lui  t2, 0x1
    addi t2, t2, -2
    bne  t1, t2, fail

    ####################################################################
    # TEST 4-10: x0 strict, negative large, chained, lui/auipc mix
    ####################################################################
    addi s0, x0, 4
    addi t0, x0, 0x8000
    addi t1, t0, -0x8000
    bne  t1, x0, fail

    addi s0, x0, 5
    lui  t0, 0xffff0
    addi t0, t0, -1
    addi t1, t0, 1
    bne  t1, x0, fail

    addi s0, x0, 6
    addi t0, x0, 1234
    add  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 7
    addi x0, x0, 9999
    bne  x0, x0, fail

    addi s0, x0, 8
    lui  t0, 0x12345
    addi t1, t0, 0x6789
    lui  t2, 0x12345
    addi t2, t2, 0x6789
    bne  t1, t2, fail

    addi s0, x0, 9
    auipc t0, 0
    auipc t1, 0
    addi t0, t0, 8
    bne  t0, t1, fail

    addi s0, x0, 10
    auipc t0, 0xfffff
    auipc t1, 0
    lui  t2, 0xfffff
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>