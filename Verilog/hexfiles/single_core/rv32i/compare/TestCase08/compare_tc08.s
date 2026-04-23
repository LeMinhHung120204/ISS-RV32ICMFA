    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Compare group test for RV32I - TEST CASE 08
    # Extra edge cases: x0 + equality + max signed
    ####################################################################
    ####################################################################
    # TEST 1-10: x0 + equality + boundary
    ####################################################################
    li s0, 1
    li t0, 0
    slt  t1, t0, x0
    bne  t1, x0, fail
    li s0, 2
    li t0, 123
    slti t1, t0, 123
    bne  t1, x0, fail
    li s0, 3
    lui  t0, 0x80000
    slti t1, t0, 0
    li t2, 1
    bne  t1, t2, fail
    li s0, 4
    li t0, -1
    sltiu t1, t0, 1
    bne  t1, x0, fail
    li s0, 5
    li t0, 0x55555555
    li t1, 0x55555555
    slt  t2, t0, t1
    bne  t2, x0, fail
    li s0, 6
    lui  t0, 0xffff0
    li t1, 0
    sltu t2, t0, t1
    bne  t2, x0, fail
    li s0, 7
    li t0, 0x7fffffff
    slti t1, t0, 0
    bne  t1, x0, fail
    li s0, 8
    li t0, -1
    sltiu t1, t0, 0
    bne  t1, x0, fail
    li s0, 9
    li t0, 1
    slt  t1, t0, x0
    bne  t1, x0, fail
    li s0, 10
    li t0, 0
    sltiu t1, t0, 1
    li t2, 1
    bne  t1, t2, fail
pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop
fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
