    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # Memory group test for RV32I - TEST CASE 05
    # Extra edge cases: heavy x0 load/store, large negative offset
    ####################################################################
    la   s1, test_mem
    ####################################################################
    # TEST 1-10: x0 heavy + signed/unsigned + overlap
    ####################################################################
    li s0, 1
    sw   x0, 0(s1)
    lw   t0, 0(s1)
    bne  t0, x0, fail
    li s0, 2
    li t0, -1
    sb   t0, 4(s1)
    lb   t1, 4(s1)
    li t2, -1
    bne  t1, t2, fail
    li s0, 3
    li t0, 0x7f
    sb   t0, -4(s1)
    lbu  t1, -4(s1)
    bne  t0, t1, fail
    li s0, 4
    lui  t0, 0x55555
    li t0, 0x555
    sw   t0, -8(s1)
    lw   t1, -8(s1)
    bne  t0, t1, fail
    li s0, 5
    li t0, -128
    sb   t0, 12(s1)
    lb   t1, 12(s1)
    li t2, -128
    bne  t1, t2, fail
    li s0, 6
    lui  t0, 0xfffff
    li t0, 0x800
    sh   t0, 14(s1)
    lh   t1, 14(s1)
    lui  t2, 0xfffff
    li t2, 0x800
    bne  t1, t2, fail
    li s0, 7
    li t0, 0x11
    sb   t0, 20(s1)
    lbu  t1, 20(s1)
    bne  t0, t1, fail
    li s0, 8
    li t0, 0x22
    sh   t0, 22(s1)
    lhu  t1, 22(s1)
    bne  t0, t1, fail
    li s0, 9
    lui  t0, 0xaaaa
    li t0, -0x556
    sw   t0, 24(s1)
    lw   t1, 24(s1)
    bne  t0, t1, fail
    li s0, 10
    sw   x0, -12(s1)
    lw   t0, -12(s1)
    bne  t0, x0, fail
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
