<FILE filename="branch_tc06.s" size="4950 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 06
    # Extra edge cases: jalr x0 (no link), self-branch, x0 behavior
    ####################################################################

    ####################################################################
    # TEST 1: jalr x0 should NOT write ra
    ####################################################################
    addi s0, x0, 1
    auipc t0, 0
    addi  t0, t0, 12
    jalr  x0, 0(t0)
    jal   x0, fail
test1_target:
    jal   x0, test1_ok
test1_ok:

    ####################################################################
    # TEST 2-10: self branch, zero compare, negative PC
    ####################################################################
    addi s0, x0, 2
    addi t0, x0, 0
    beq  t0, x0, test2_ok
    jal  x0, fail
test2_ok:

    addi s0, x0, 3
    addi t0, x0, 1
    bne  t0, x0, test3_ok
    jal  x0, fail
test3_ok:

    addi s0, x0, 4
    addi t0, x0, 5
    addi t1, x0, 0
loop4:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop4
    addi t2, x0, 5
    bne  t1, t2, fail

    addi s0, x0, 5
    auipc t0, 0
    addi  t0, t0, 8
    jalr  t1, -8(t0)
    jal   x0, fail
test5_target:
    auipc t2, 0
    addi  t2, t2, -12
    bne   t1, t2, fail

    addi s0, x0, 6
    addi t0, x0, -1
    addi t1, x0, 0
    bltu t1, t0, test6_ok
    jal  x0, fail
test6_ok:

    addi s0, x0, 7
    addi t0, x0, 0x80000000
    addi t1, x0, 0
    blt  t0, t1, test7_ok
    jal  x0, fail
test7_ok:

    addi s0, x0, 8
    addi t0, x0, 0
    addi t1, x0, 0
    bge  t0, t1, test8_ok
    jal  x0, fail
test8_ok:

    addi s0, x0, 9
    addi t0, x0, 0x7fffffff
    addi t1, x0, 0x80000000
    bge  t0, t1, test9_ok
    jal  x0, fail
test9_ok:

    addi s0, x0, 10
    addi t0, x0, 0
    addi t1, x0, -1
    bgeu t0, t1, test10_ok
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