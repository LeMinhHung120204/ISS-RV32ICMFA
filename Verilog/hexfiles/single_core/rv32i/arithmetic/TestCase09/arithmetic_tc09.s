<FILE filename="arithmetic_tc09.s" size="5590 bytes">
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
    addi s0, x0, 1
    auipc t0, 0x7ff
    auipc t1, 0
    lui  t2, 0x7ff
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    addi s0, x0, 2
    auipc t0, 0x800
    auipc t1, 0
    lui  t2, 0x800
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    addi s0, x0, 3
    addi t0, x0, 0xaaaaaaaa
    addi t1, t0, 0x55555556
    bne  t1, x0, fail

    addi s0, x0, 4
    addi t0, x0, 0x7fffffff
    addi t1, t0, 1
    lui  t2, 0x80000
    bne  t1, t2, fail

    addi s0, x0, 5
    addi t0, x0, -1
    sub  t1, t0, t0
    bne  t1, x0, fail

    addi s0, x0, 6
    addi x0, x0, 0x12345678
    bne  x0, x0, fail

    addi s0, x0, 7
    lui  t0, 0xffff0
    addi t1, t0, 0x1000
    bne  t1, x0, fail

    addi s0, x0, 8
    addi t0, x0, 2047
    addi t1, t0, -2048
    addi t2, t1, 1
    bne  t2, x0, fail

    addi s0, x0, 9
    addi t0, x0, 0
    addi t1, t0, 0x7ff
    addi t2, t1, 0x7ff
    lui  t3, 0x1
    addi t3, t3, -2
    bne  t2, t3, fail

    addi s0, x0, 10
    lui  t0, 0x80000
    addi t1, t0, 0x7fffffff
    addi t2, t1, 1
    bne  t2, x0, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>