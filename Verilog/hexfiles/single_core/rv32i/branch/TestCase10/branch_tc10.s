    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 10 (FINAL)
    # Comprehensive mix of all branch instructions + edge cases
    ####################################################################
    ####################################################################
    # TEST 1-10: full coverage of beq/bne/blt/bge/bltu/bgeu/jal/jalr
    ####################################################################
    li s0, 1
    li t0, 0x55555555
    li t1, 0xaaaaaaaa
    bne  t0, t1, test1_ok
    jal  x0, fail
test1_ok:
    li s0, 2
    lui  t0, 0x80000
    li t1, 0
    blt  t0, t1, test2_ok
    jal  x0, fail
test2_ok:
    li s0, 3
    li t0, -1
    li t1, 1
    bgeu t0, t1, test3_ok
    jal  x0, fail
test3_ok:
    li s0, 4
    li t2, 0
    jal  x0, test4_skip
    li t2, 1
test4_skip:
    bne  t2, x0, fail
    li s0, 5
    auipc t0, 0
    addi  t0, t0, 24
    jalr  t1, -20(t0)
    jal   x0, fail
test5_target:
    auipc t2, 0
    addi  t2, t2, -28
    bne   t1, t2, fail
    li s0, 6
    li t0, 10
    li t1, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop6
    li t2, 10
    bne  t1, t2, fail
    li s0, 7
    li t0, 0
    li t1, 0
    beq  t0, t1, test7_ok
    jal  x0, fail
test7_ok:
    li s0, 8
    li t0, 0x7fffffff
    li t1, 0x80000000
    blt  t0, t1, test8_ok
    jal  x0, fail
test8_ok:
    li s0, 9
    li t0, -1
    li t1, -1
    bge  t0, t1, test9_ok
    jal  x0, fail
test9_ok:
    li s0, 10
    li t0, 0
    li t1, -1
    bltu t0, t1, test10_ok
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
