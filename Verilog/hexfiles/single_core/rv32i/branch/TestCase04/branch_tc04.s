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
    li s0, 1
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
    li s0, 2
    li t2, 0
    jal  x0, test2_far
    li t2, 1
    li t2, 2
    li t2, 3
    li t2, 4
test2_far:
    bne  t2, x0, fail
    li s0, 3
    li t0, 0x7fffffff
    li t1, 0x80000000
    blt  t0, t1, test3_ok
    jal  x0, fail
test3_ok:
    li s0, 4
    li t0, 5
    li t1, 5
    bne  t0, t1, fail
    li s0, 5
    li t0, 0
    li t1, -1
    bgeu t0, t1, test5_ok
    jal  x0, fail
test5_ok:
    li s0, 6
    li t0, 3
    li t1, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop6
    li t2, 3
    bne  t1, t2, fail
    li s0, 7
    li x0, 0   # x0 test
    bne  x0, x0, fail
    li s0, 8
    auipc t0, 0
    addi  t0, t0, 12
    jalr  t1, 0(t0)
    jal   x0, fail
test8_target:
    auipc t2, 0
    addi  t2, t2, -16
    bne   t1, t2, fail
    li s0, 9
    li t0, -1
    li t1, 1
    blt  t0, t1, test9_ok
    jal  x0, fail
test9_ok:
    li s0, 10
    li t0, 0
    li t1, 0
    bge  t0, t1, test10_ok
    jal  x0, fail
test10_ok:
pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop
fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
