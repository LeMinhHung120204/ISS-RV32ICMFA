<FILE filename="branch_tc07.s" size="5020 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 07
    # Extra edge cases: chained branches, large immediate compare
    ####################################################################

    ####################################################################
    # TEST 1-10: chained conditional branches + jalr
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, 10
    addi t1, x0, 0
    bge  t0, x0, test1_ok
    jal  x0, fail
test1_ok:

    addi s0, x0, 2
    addi t0, x0, -10
    blt  t0, x0, test2_ok
    jal  x0, fail
test2_ok:

    addi s0, x0, 3
    addi t0, x0, 0x55555555
    addi t1, x0, 0x55555555
    beq  t0, t1, test3_ok
    jal  x0, fail
test3_ok:

    addi s0, x0, 4
    auipc t0, 0
    addi  t0, t0, 20
    jalr  t1, 0(t0)
    jal   x0, fail
test4_target:
    auipc t2, 0
    addi  t2, t2, -24
    bne   t1, t2, fail

    addi s0, x0, 5
    addi t2, x0, 0
    jal  x0, test5_skip
    addi t2, x0, 1
    addi t2, x0, 2
    addi t2, x0, 3
test5_skip:
    bne  t2, x0, fail

    addi s0, x0, 6
    addi t0, x0, 0
    addi t1, x0, -1
    bltu t0, t1, test6_ok
    jal  x0, fail
test6_ok:

    addi s0, x0, 7
    addi t0, x0, 5
    addi t1, x0, 0
loop7:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop7
    addi t2, x0, 5
    bne  t1, t2, fail

    addi s0, x0, 8
    addi t0, x0, 0x80000000
    addi t1, x0, 0x7fffffff
    bgeu t0, t1, test8_ok
    jal  x0, fail
test8_ok:

    addi s0, x0, 9
    addi t0, x0, -2048
    addi t1, x0, -2048
    beq  t0, t1, test9_ok
    jal  x0, fail
test9_ok:

    addi s0, x0, 10
    addi t0, x0, 0
    addi t1, x0, 1
    blt  t0, t1, test10_ok
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