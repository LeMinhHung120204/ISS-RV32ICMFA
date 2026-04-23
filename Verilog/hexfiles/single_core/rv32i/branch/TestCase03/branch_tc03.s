    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 03
    # Extra edge cases: 0x55555555 / 0xAAAAAAAA patterns, jalr complex
    ####################################################################
    ####################################################################
    # TEST 1: beq with 0x55555555
    ####################################################################
    li s0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    lui  t1, 0x55555
    addi t1, t1, 0x555
    beq  t0, t1, test1_ok
    jal  x0, fail
test1_ok:
    ####################################################################
    # TEST 2: bne with 0xAAAAAAAA
    ####################################################################
    li s0, 2
    lui  t0, 0xaaaa
    addi t0, t0, -0x556
    lui  t1, 0xaaaa
    addi t1, t1, -0x555
    bne  t0, t1, test2_ok
    jal  x0, fail
test2_ok:
    ####################################################################
    # TEST 3: blt signed 0x80000000 < 0x7fffffff taken
    ####################################################################
    li s0, 3
    lui  t0, 0x80000
    lui  t1, 0x7ffff
    addi t1, t1, -1
    blt  t0, t1, test3_ok
    jal  x0, fail
test3_ok:
    ####################################################################
    # TEST 4-10: more jal/jalr, offset, loop variants
    ####################################################################
    li s0, 4
    auipc t0, 0
    addi  t0, t0, 16
    jalr  t1, 0(t0)
    jal   x0, fail
    jal   x0, fail
test4_target:
    auipc t2, 0
    addi  t2, t2, -20
    bne   t1, t2, fail
    li s0, 5
    li t2, 0
    jal  x0, test5_skip
    li t2, 99
test5_skip:
    bne  t2, x0, fail
    li s0, 6
    li t0, 10
    li t1, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bge  t0, x0, loop6
    li t2, 10
    bne  t1, t2, fail
    li s0, 7
    li t0, -5
    li t1, 0
loop7:
    addi t1, t1, 1
    addi t0, t0, 1
    blt  t0, x0, loop7
    li t2, 5
    bne  t1, t2, fail
    li s0, 8
    auipc t0, 0
    addi  t0, t0, 8
    jalr  x0, 0(t0)   # jalr x0 should not write ra
    jal   x0, fail
test8_target2:
    jal   x0, test8_ok
test8_ok:
    li s0, 9
    li t0, 0
    li t1, 0
    beq  t0, t1, test9_ok
    jal  x0, fail
test9_ok:
    li s0, 10
    li t0, -1
    li t1, 0
    bltu t0, t1, fail   # unsigned -1 is max
pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop
fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
