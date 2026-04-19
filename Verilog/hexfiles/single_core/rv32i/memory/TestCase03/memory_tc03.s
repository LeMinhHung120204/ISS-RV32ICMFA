<FILE filename="memory_tc03.s" size="6280 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Memory group test for RV32I - TEST CASE 03
    # Extra edge cases: 0x55555555 pattern, large negative offset
    ####################################################################

    la   s1, test_mem

    ####################################################################
    # TEST 1: sw 0x55555555 + lw
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    sw   t0, 0(s1)
    lw   t1, 0(s1)
    bne  t0, t1, fail

    ####################################################################
    # TEST 2: sb 0xAA + lbu
    ####################################################################
    addi s0, x0, 2
    addi t0, x0, 0xAA
    sb   t0, 4(s1)
    lbu  t1, 4(s1)
    bne  t0, t1, fail

    ####################################################################
    # TEST 3-10: more overlap, negative offset, x0
    ####################################################################
    addi s0, x0, 3
    addi t0, x0, -1
    sb   t0, -4(s1)
    lb   t1, -4(s1)
    addi t2, x0, -1
    bne  t1, t2, fail

    addi s0, x0, 4
    lui  t0, 0x55555
    addi t0, t0, 0x555
    sw   t0, -8(s1)
    lw   t1, -8(s1)
    bne  t0, t1, fail

    addi s0, x0, 5
    addi t0, x0, 0x11
    sb   t0, 12(s1)
    lbu  t1, 12(s1)
    bne  t0, t1, fail

    addi s0, x0, 6
    addi t0, x0, 0x22
    sh   t0, 14(s1)
    lhu  t1, 14(s1)
    bne  t0, t1, fail

    addi s0, x0, 7
    sw   x0, 16(s1)
    lw   t0, 16(s1)
    bne  t0, x0, fail

    addi s0, x0, 8
    addi t0, x0, -128
    sb   t0, -12(s1)
    lb   t1, -12(s1)
    addi t2, x0, -128
    bne  t1, t2, fail

    addi s0, x0, 9
    lui  t0, 0xfffff
    addi t0, t0, 0x800
    sh   t0, -14(s1)
    lh   t1, -14(s1)
    lui  t2, 0xfffff
    addi t2, t2, 0x800
    bne  t1, t2, fail

    addi s0, x0, 10
    lui  t0, 0x55555
    addi t0, t0, 0x555
    sw   t0, 20(s1)
    lw   t1, 20(s1)
    bne  t0, t1, fail

pass:
    addi a0, x0, 1
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
</FILE>