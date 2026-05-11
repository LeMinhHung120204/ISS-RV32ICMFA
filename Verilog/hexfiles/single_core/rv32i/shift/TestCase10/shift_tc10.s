    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 10 (FINAL)
    # Comprehensive mix of all shift instructions + edge cases
    ####################################################################

    ####################################################################
    # TEST 1-10: full coverage of sll/slli/srl/srli/sra/srai
    ####################################################################
    li s0, 1
    li t0, 0x55555555
    li t1, 1
    sll  t2, t0, t1
    lui  t3, 0xaaaa
    li t3, -0x556
    bne  t2, t3, fail

    li s0, 2
    lui  t0, 0xaaaa
    li t0, -0x556
    li t1, 1
    srl  t2, t0, t1
    lui  t3, 0x55555
    addi t3, t3, 0x555
    bne  t2, t3, fail

    li s0, 3
    lui  t0, 0x80000
    li t1, 31
    sra  t2, t0, t1
    li t3, -1
    bne  t2, t3, fail

    li s0, 4
    li t0, 1
    slli t1, t0, 0
    bne  t1, t0, fail

    li s0, 5
    li t0, 0xaaaaaaaa
    srli t1, t0, 0
    bne  t1, t0, fail

    li s0, 6
    li t0, -1
    srai t1, t0, 0
    bne  t1, t0, fail

    li s0, 7
    li t0, 1
    sll  t1, t0, x0
    bne  t1, t0, fail

    li s0, 8
    li t0, 0x80000000
    sra  t1, t0, x0
    bne  t1, t0, fail

    li s0, 9
    li t0, 0x7fffffff
    slli t1, t0, 31
    lui  t2, 0x80000
    li t2, -0x80000000
    bne  t1, t2, fail

    li s0, 10
    li t0, -1
    srli t1, t0, 31
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
