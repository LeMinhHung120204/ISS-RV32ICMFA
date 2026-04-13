    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I
    # Tested instructions:
    #   beq, bne, blt, bge, bltu, bgeu, jal, jalr
    ####################################################################

    ####################################################################
    # TEST 1: beq taken
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, 5
    addi t1, x0, 5
    beq  t0, t1, test1_ok
    jal  x0, fail
test1_ok:

    ####################################################################
    # TEST 2: beq not taken
    ####################################################################
    addi s0, x0, 2
    addi t0, x0, 5
    addi t1, x0, 6
    beq  t0, t1, fail

    ####################################################################
    # TEST 3: bne taken
    ####################################################################
    addi s0, x0, 3
    addi t0, x0, 1
    addi t1, x0, 2
    bne  t0, t1, test3_ok
    jal  x0, fail
test3_ok:

    ####################################################################
    # TEST 4: bne not taken
    ####################################################################
    addi s0, x0, 4
    addi t0, x0, 7
    addi t1, x0, 7
    bne  t0, t1, fail

    ####################################################################
    # TEST 5: blt signed, -1 < 1 taken
    ####################################################################
    addi s0, x0, 5
    addi t0, x0, -1
    addi t1, x0, 1
    blt  t0, t1, test5_ok
    jal  x0, fail
test5_ok:

    ####################################################################
    # TEST 6: bge signed, 1 >= -1 taken
    ####################################################################
    addi s0, x0, 6
    addi t0, x0, 1
    addi t1, x0, -1
    bge  t0, t1, test6_ok
    jal  x0, fail
test6_ok:

    ####################################################################
    # TEST 7: bltu unsigned, 0 < 0xffffffff taken
    ####################################################################
    addi s0, x0, 7
    addi t0, x0, 0
    addi t1, x0, -1
    bltu t0, t1, test7_ok
    jal  x0, fail
test7_ok:

    ####################################################################
    # TEST 8: bgeu unsigned, 0xffffffff >= 1 taken
    ####################################################################
    addi s0, x0, 8
    addi t0, x0, -1
    addi t1, x0, 1
    bgeu t0, t1, test8_ok
    jal  x0, fail
test8_ok:

    ####################################################################
    # TEST 9: jal writes return address
    ####################################################################
    addi s0, x0, 9
    jal  t0, test9_target
    jal  x0, fail
test9_target:
    auipc t1, 0
    addi  t1, t1, -4
    bne   t0, t1, fail

    ####################################################################
    # TEST 10: jal skips over instruction
    ####################################################################
    addi s0, x0, 10
    addi t2, x0, 0
    jal  x0, test10_skip
    addi t2, x0, 1
test10_skip:
    bne  t2, x0, fail

    ####################################################################
    # TEST 11: jalr via register target
    ####################################################################
    addi s0, x0, 11
    auipc t0, 0
    addi  t0, t0, 12
    jalr  t1, 0(t0)
    jal   x0, fail
    jal   x0, fail
test11_target:
    auipc t2, 0
    addi  t2, t2, -12
    bne   t1, t2, fail

    ####################################################################
    # TEST 12: self-consistency small loop by bne
    ####################################################################
    addi s0, x0, 12
    addi t0, x0, 3
    addi t1, x0, 0
loop12:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop12
    addi t2, x0, 3
    bne  t1, t2, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop