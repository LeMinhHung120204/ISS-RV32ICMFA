<FILE filename="branch_tc04.s" size="5050 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 04
    # Extra edge cases: large forward/backward branches, jalr negative offset
    ####################################################################

    ####################################################################
    # TEST 1-10: focus on jalr, long branches, mixed conditions
    ####################################################################
    addi s0, x0, 1
    auipc t0, 0
    addi  t0, t0, 24
    jalr  t1, -20(t0)
    jal   x0, fail
    jal   x0, fail
    jal   x0, fail
test1_target:
    auipc t2, 0
    addi  t2, t2, -28
    bne   t1, t2, fail

    addi s0, x0, 2
    addi t2, x0, 0
    jal  x0, test2_far
    addi t2, x0, 1
    addi t2, x0, 2
    addi t2, x0, 3
    addi t2, x0, 4
test2_far:
    bne  t2, x0, fail

    addi s0, x0, 3
    addi t0, x0, 0x7fffffff
    addi t1, x0, 0x80000000
    blt  t0, t1, test3_ok
    jal  x0, fail
test3_ok:

    addi s0, x0, 4
    addi t0, x0, 5
    addi t1, x0, 5
    bne  t0, t1, fail

    addi s0, x0, 5
    addi t0, x0, 0
    addi t1, x0, -1
    bgeu t0, t1, test5_ok
    jal  x0, fail
test5_ok:

    addi s0, x0, 6
    addi t0, x0, 3
    addi t1, x0, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop6
    addi t2, x0, 3
    bne  t1, t2, fail

    addi s0, x0, 7
    addi x0, x0, 0   # x0 test
    bne  x0, x0, fail

    addi s0, x0, 8
    auipc t0, 0
    addi  t0, t0, 12
    jalr  t1, 0(t0)
    jal   x0, fail
test8_target:
    auipc t2, 0
    addi  t2, t2, -16
    bne   t1, t2, fail

    addi s0, x0, 9
    addi t0, x0, -1
    addi t1, x0, 1
    blt  t0, t1, test9_ok
    jal  x0, fail
test9_ok:

    addi s0, x0, 10
    addi t0, x0, 0
    addi t1, x0, 0
    bge  t0, t1, test10_ok
    jal  x0, fail
test10_ok:

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>