<FILE filename="arithmetic_tc04.s" size="5620 bytes">
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
    addi s0, x0, 1
    lui  t0, 0xffff0
    lui  t1, 0x1
    add  t2, t0, t1
    bne  t2, x0, fail

    ####################################################################
    # TEST 2: sub 0x80000000 - 0x7fffffff = 1
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0x80000
    lui  t1, 0x7ffff
    addi t1, t1, -1
    sub  t2, t0, t1
    addi t3, x0, 1
    bne  t2, t3, fail

    ####################################################################
    # TEST 3-10: chained ops, x0, auipc large offset, etc.
    ####################################################################
    addi s0, x0, 3
    addi t0, x0, 0x7fffffff
    addi t1, t0, 1
    lui  t2, 0x80000
    bne  t1, t2, fail

    addi s0, x0, 4
    addi t0, x0, 0
    addi t1, t0, -1
    addi t2, t1, -1
    addi t3, x0, -2
    bne  t2, t3, fail

    addi s0, x0, 5
    addi t0, x0, 0x5555
    addi t1, t0, 0x5555
    lui  t2, 0xaaaa a
    addi t2, t2, -0x556
    bne  t1, t2, fail

    addi s0, x0, 6
    addi x0, x0, 0x1234
    bne  x0, x0, fail

    addi s0, x0, 7
    auipc t0, 0x10
    auipc t1, 0
    lui  t2, 0x10
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    addi s0, x0, 8
    auipc t0, 0xfffe0
    auipc t1, 0
    lui  t2, 0xfffe0
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    addi s0, x0, 9
    addi t0, x0, 0
    addi t1, t0, 2047
    addi t2, t1, 2047
    lui  t3, 0x1
    addi t3, t3, -2
    bne  t2, t3, fail

    addi s0, x0, 10
    lui  t0, 0x80000
    addi t0, t0, -1
    addi t1, t0, 2
    lui  t2, 0x80000
    addi t2, t2, 1
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