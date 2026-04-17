<FILE filename="arithmetic_tc05.s" size="5510 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 05
    # Extra edge cases: 0xFFFF FFFF pattern, signed/unsigned boundary
    ####################################################################

    ####################################################################
    # TEST 1: add 0xFFFFFFFF + 1 = 0
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, -1
    addi t1, x0, 1
    add  t2, t0, t1
    bne  t2, x0, fail

    ####################################################################
    # TEST 2: sub 0x00000001 - 0x80000000 = 0x7FFFFFFF (wrap)
    ####################################################################
    addi s0, x0, 2
    addi t0, x0, 1
    lui  t1, 0x80000
    sub  t2, t0, t1
    lui  t3, 0x7ffff
    addi t3, t3, -1
    bne  t2, t3, fail

    ####################################################################
    # TEST 3-10: more chained, x0, auipc, etc.
    ####################################################################
    addi s0, x0, 3
    addi t0, x0, -2048
    addi t1, t0, 2047
    addi t2, t1, 1
    bne  t2, x0, fail

    addi s0, x0, 4
    lui  t0, 0xaaaa a
    addi t0, t0, -0x556
    add  t1, t0, t0
    lui  t2, 0x55555
    addi t2, t2, 0x554
    bne  t1, t2, fail

    addi s0, x0, 5
    addi t0, x0, 0
    addi x0, t0, 0x123
    bne  x0, t0, fail

    addi s0, x0, 6
    auipc t0, 0
    addi t0, t0, 0
    bne  t0, t0, fail   # trivial but tests PC

    addi s0, x0, 7
    auipc t0, 0x7ff
    auipc t1, 0
    lui  t2, 0x7ff
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    addi s0, x0, 8
    addi t0, x0, 0x7fffffff
    addi t1, t0, -0x7fffffff
    addi t2, t1, -1
    bne  t2, x0, fail

    addi s0, x0, 9
    lui  t0, 0x00001
    addi t1, t0, -1
    bne  t1, x0, fail

    addi s0, x0, 10
    addi t0, x0, 0x55555555
    addi t1, t0, 0x55555555
    lui  t2, 0xaaaa a
    addi t2, t2, -0x556
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