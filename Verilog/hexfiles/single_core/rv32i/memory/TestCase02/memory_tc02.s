    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Memory group test for RV32I - TEST CASE 02
    # Extra edge cases: negative offsets, byte/half overlap, x0 load/store
    ####################################################################
    la   s1, test_mem
    ####################################################################
    # TEST 1: lw with negative offset
    ####################################################################
    li s0, 1
    lui  t0, 0x12345
    li t0, 0x678
    sw   t0, 4(s1)
    lw   t1, -4(s1)
    bne  t0, t1, fail
    ####################################################################
    # TEST 2: sb negative offset + lbu
    ####################################################################
    li s0, 2
    li t0, 0x7f
    sb   t0, -4(s1)
    lbu  t1, -4(s1)
    bne  t0, t1, fail
    ####################################################################
    # TEST 3: sh negative offset + lh sign extend
    ####################################################################
    li s0, 3
    li t0, -1
    sh   t0, -6(s1)
    lh   t1, -6(s1)
    li t2, -1
    bne  t1, t2, fail
    ####################################################################
    # TEST 4: sw/lw with x0 source
    ####################################################################
    li s0, 4
    sw   x0, 8(s1)
    lw   t0, 8(s1)
    bne  t0, x0, fail
    ####################################################################
    # TEST 5: byte/half/word overlap test
    ####################################################################
    li s0, 5
    li t0, 0x11
    li t1, 0x22
    li t2, 0x33
    li t3, 0x44
    sb   t0, 12(s1)
    sb   t1, 13(s1)
    sb   t2, 14(s1)
    sb   t3, 15(s1)
    lw   t4, 12(s1)
    lui  t5, 0x44332
    li t5, 0x211
    bne  t4, t5, fail
    ####################################################################
    # TEST 6-10: x0 load, negative large, unaligned byte/half
    ####################################################################
    li s0, 6
    lw   t0, 0(s1)
    bne  t0, x0, fail   # x0 load test
    li s0, 7
    li t0, -128
    sb   t0, -8(s1)
    lb   t1, -8(s1)
    li t2, -128
    bne  t1, t2, fail
    li s0, 8
    lui  t0, 0xfffff
    li t0, 0x800
    sh   t0, -10(s1)
    lh   t1, -10(s1)
    lui  t2, 0xfffff
    li t2, 0x800
    bne  t1, t2, fail
    li s0, 9
    li t0, 0x7f
    sb   t0, 20(s1)
    lbu  t1, 20(s1)
    bne  t0, t1, fail
    li s0, 10
    li t0, -1
    sh   t0, 22(s1)
    lhu  t1, 22(s1)
    lui  t2, 0x10
    li t2, -1
    bne  t1, t2, fail
pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop
fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
    .section .data
    .align 4
test_mem:
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
