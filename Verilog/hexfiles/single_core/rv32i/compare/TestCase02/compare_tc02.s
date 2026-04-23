    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Compare group test for RV32I - TEST CASE 02
    # Extra edge cases: 0x55555555 / 0xAAAAAAAA, signed max/min
    ####################################################################
    ####################################################################
    # TEST 1: slt 0x55555555  1 (signed)
    ####################################################################
    li s0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    lui  t1, 0xaaaa
    li t1, -0x556
    slt  t2, t0, t1
    li t3, 1
    bne  t2, t3, fail
    ####################################################################
    # TEST 2: sltu 0x55555555  1 (unsigned)
    ####################################################################
    li s0, 2
    sltu t2, t0, t1
    li t3, 1
    bne  t2, t3, fail
    ####################################################################
    # TEST 3: slt 0x80000000  1 (signed)
    ####################################################################
    li s0, 3
    lui  t0, 0x80000
    li t1, 0
    slt  t2, t0, t1
    li t3, 1
    bne  t2, t3, fail
    ####################################################################
    # TEST 4-10: slti/sltiu edge + x0
    ####################################################################
    li s0, 4
    li t0, 0x7fffffff
    slti t1, t0, 0
    bne  t1, x0, fail
    li s0, 5
    li t0, -1
    sltiu t1, t0, 0
    bne  t1, x0, fail
    li s0, 6
    li t0, 0
    slt  t1, t0, x0
    bne  t1, x0, fail
    li s0, 7
    li t0, 123
    slti t1, t0, 123
    bne  t1, x0, fail
    li s0, 8
    lui  t0, 0x80000
    slti t1, t0, 0
    li t2, 1
    bne  t1, t2, fail
    li s0, 9
    li t0, -1
    sltiu t1, t0, 1
    bne  t1, x0, fail
    li s0, 10
    li t0, 0x55555555
    li t1, 0x55555555
    slt  t2, t0, t1
    bne  t2, x0, fail
pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop
fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
