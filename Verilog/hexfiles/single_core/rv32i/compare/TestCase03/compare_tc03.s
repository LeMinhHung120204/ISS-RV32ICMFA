<FILE filename="compare_tc03.s" size="5180 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Compare group test for RV32I - TEST CASE 03
    # Extra edge cases: 0xFFFF0000, signed/unsigned boundary
    ####################################################################

    ####################################################################
    # TEST 1: slt 0xFFFF0000 < 0 -> 1 (signed)
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0xffff0
    addi t1, x0, 0
    slt  t2, t0, t1
    addi t3, x0, 1
    bne  t2, t3, fail

    ####################################################################
    # TEST 2: sltu 0xFFFF0000 < 0 -> 0 (unsigned)
    ####################################################################
    addi s0, x0, 2
    sltu t2, t0, t1
    bne  t2, x0, fail

    ####################################################################
    # TEST 3-10: slti/sltiu + x0
    ####################################################################
    addi s0, x0, 3
    addi t0, x0, 0x80000000
    slti t1, t0, 0
    addi t2, x0, 1
    bne  t1, t2, fail

    addi s0, x0, 4
    addi t0, x0, -1
    sltiu t1, t0, 0
    bne  t1, x0, fail

    addi s0, x0, 5
    addi t0, x0, 0
    slt  t1, t0, x0
    bne  t1, x0, fail

    addi s0, x0, 6
    addi t0, x0, 123
    slti t1, t0, 123
    bne  t1, x0, fail

    addi s0, x0, 7
    lui  t0, 0x80000
    slti t1, t0, 0
    addi t2, x0, 1
    bne  t1, t2, fail

    addi s0, x0, 8
    addi t0, x0, -1
    sltiu t1, t0, 1
    bne  t1, x0, fail

    addi s0, x0, 9
    addi t0, x0, 0x55555555
    addi t1, x0, 0x55555555
    slt  t2, t0, t1
    bne  t2, x0, fail

    addi s0, x0, 10
    lui  t0, 0xffff0
    addi t1, x0, 0
    sltu t2, t0, t1
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