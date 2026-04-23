    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 09
    # Extra edge cases: heavy jalr offset, mixed signed/unsigned
    ####################################################################
    ####################################################################
    # TEST 1-10: jalr with large negative/positive offset
    ####################################################################
    li s0, 1
    auipc t0, 0
    addi  t0, t0, 32
    jalr  t1, -28(t0)
    jal   x0, fail
test1_target:
    auipc t2, 0
    addi  t2, t2, -36
    bne   t1, t2, fail
    li s0, 2
    li t0, 0x7fffffff
    li t1, 0
    bge  t0, t1, test2_ok
    jal  x0, fail
test2_ok:
    li s0, 3
    li t0, -1
    li t1, 0
    bltu t1, t0, test3_ok
    jal  x0, fail
test3_ok:
    li s0, 4
    li t2, 0
    jal  x0, test4_skip
    li t2, 99
test4_skip:
    bne  t2, x0, fail
    li s0, 5
    li t0, 0
    li t1, -2048
    blt  t1, t0, test5_ok
    jal  x0, fail
test5_ok:
    li s0, 6
    li t0, 5
    li t1, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop6
    li t2, 5
    bne  t1, t2, fail
    li s0, 7
    li t0, 0xaaaaaaaa
    li t1, 0xaaaaaaaa
    beq  t0, t1, test7_ok
    jal  x0, fail
test7_ok:
    li s0, 8
    li t0, 0x55555555
    li t1, 0x55555555
    bne  t0, t1, fail
    li s0, 9
    auipc t0, 0
    addi  t0, t0, 12
    jalr  t1, 0(t0)
    jal   x0, fail
test9_target:
    auipc t2, 0
    addi  t2, t2, -16
    bne   t1, t2, fail
    li s0, 10
    li t0, 0x80000000
    li t1, 0x80000000
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
