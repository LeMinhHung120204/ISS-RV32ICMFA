    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 02
    # Extra edge cases: signed/unsigned boundary, zero, negative max
    ####################################################################
    ####################################################################
    # TEST 1: beq taken with 0xFFFFFFFF
    ####################################################################
    li s0, 1
    li t0, -1
    li t1, -1
    beq  t0, t1, test1_ok
    jal  x0, fail
test1_ok:
    ####################################################################
    # TEST 2: beq not taken with max positive
    ####################################################################
    li s0, 2
    li t0, 0x7fffffff
    li t1, 0x7ffffffe
    beq  t0, t1, fail
    ####################################################################
    # TEST 3: bne taken with negative values
    ####################################################################
    li s0, 3
    li t0, -2048
    li t1, -2047
    bne  t0, t1, test3_ok
    jal  x0, fail
test3_ok:
    ####################################################################
    # TEST 4: blt signed, 0x80000000 < 0 taken
    ####################################################################
    li s0, 4
    lui  t0, 0x80000
    li t1, 0
    blt  t0, t1, test4_ok
    jal  x0, fail
test4_ok:
    ####################################################################
    # TEST 5: bge signed, 0x7fffffff = 0x80000000 taken
    ####################################################################
    li s0, 5
    lui  t0, 0x7ffff
    addi t0, t0, -1
    lui  t1, 0x80000
    bge  t0, t1, test5_ok
    jal  x0, fail
test5_ok:
    ####################################################################
    # TEST 6: bltu unsigned, 0x7fffffff < 0x80000000 taken
    ####################################################################
    li s0, 6
    lui  t0, 0x7ffff
    addi t0, t0, -1
    lui  t1, 0x80000
    bltu t0, t1, test6_ok
    jal  x0, fail
test6_ok:
    ####################################################################
    # TEST 7: bgeu unsigned, 0x80000000 = 0x7fffffff taken
    ####################################################################
    li s0, 7
    lui  t0, 0x80000
    lui  t1, 0x7ffff
    addi t1, t1, -1
    bgeu t0, t1, test7_ok
    jal  x0, fail
test7_ok:
    ####################################################################
    # TEST 8: jalr with offset 0 and negative base
    ####################################################################
    li s0, 8
    auipc t0, 0
    addi  t0, t0, 20
    jalr  t1, -20(t0)
    jal   x0, fail
test8_target:
    auipc t2, 0
    addi  t2, t2, -24
    bne   t1, t2, fail
    ####################################################################
    # TEST 9: forward branch over many instructions
    ####################################################################
    li s0, 9
    li t2, 0
    jal  x0, test9_skip
    li t2, 1
    li t2, 2
    li t2, 3
test9_skip:
    bne  t2, x0, fail
    ####################################################################
    # TEST 10: backward branch loop 5 times
    ####################################################################
    li s0, 10
    li t0, 5
    li t1, 0
loop10:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop10
    li t2, 5
    bne  t1, t2, fail
pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop
fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
