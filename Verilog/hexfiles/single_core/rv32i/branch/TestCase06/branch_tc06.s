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
    li s0, 1
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
    li s0, 2
    li t0, 0
    beq  t0, x0, test2_ok
    jal  x0, fail
test2_ok:
    li s0, 3
    li t0, 1
    bne  t0, x0, test3_ok
    jal  x0, fail
test3_ok:
    li s0, 4
    li t0, 5
    li t1, 0
loop4:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop4
    li t2, 5
    bne  t1, t2, fail
    li s0, 5
    auipc t0, 0
    addi  t0, t0, 8
    jalr  t1, -8(t0)
    jal   x0, fail
test5_target:
    auipc t2, 0
    addi  t2, t2, -12
    bne   t1, t2, fail
    li s0, 6
    li t0, -1
    li t1, 0
    bltu t1, t0, test6_ok
    jal  x0, fail
test6_ok:
    li s0, 7
    li t0, 0x80000000
    li t1, 0
    blt  t0, t1, test7_ok
    jal  x0, fail
test7_ok:
    li s0, 8
    li t0, 0
    li t1, 0
    bge  t0, t1, test8_ok
    jal  x0, fail
test8_ok:
    li s0, 9
    li t0, 0x7fffffff
    li t1, 0x80000000
    bge  t0, t1, test9_ok
    jal  x0, fail
test9_ok:
    li s0, 10
    li t0, 0
    li t1, -1
    bgeu t0, t1, test10_ok
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
