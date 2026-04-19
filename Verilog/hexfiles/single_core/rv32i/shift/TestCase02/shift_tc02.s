<FILE filename="shift_tc02.s" size="4980 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 02
    # Extra edge cases: 0x55555555 / 0xAAAAAAAA patterns, shift by 0/31/32
    ####################################################################

    ####################################################################
    # TEST 1: sll 0x55555555 << 1 = 0xAAAAAAAA
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    addi t1, x0, 1
    sll  t2, t0, t1
    lui  t3, 0xaaaa a
    addi t3, t3, -0x556
    bne  t2, t3, fail

    ####################################################################
    # TEST 2: srl 0xAAAAAAAA >> 1 = 0x55555555
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0xaaaa a
    addi t0, t0, -0x556
    addi t1, x0, 1
    srl  t2, t0, t1
    lui  t3, 0x55555
    addi t3, t3, 0x555
    bne  t2, t3, fail

    ####################################################################
    # TEST 3: sra 0x80000000 >> 31 = 0xFFFFFFFF
    ####################################################################
    addi s0, x0, 3
    lui  t0, 0x80000
    addi t1, x0, 31
    sra  t2, t0, t1
    addi t3, x0, -1
    bne  t2, t3, fail

    ####################################################################
    # TEST 4-10: slli/srli/srai with shamt 0/32 + x0
    ####################################################################
    addi s0, x0, 4
    addi t0, x0, 0x55555555
    slli t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 5
    addi t0, x0, 0xaaaaaaaa
    srli t1, t0, 32
    bne  t1, t0, fail

    addi s0, x0, 6
    addi t0, x0, -1
    srai t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 7
    addi t0, x0, 1
    sll  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 8
    addi t0, x0, 0x80000000
    sra  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 9
    addi t0, x0, 0x7fffffff
    slli t1, t0, 31
    lui  t2, 0x80000
    addi t2, t2, -0x80000000
    bne  t1, t2, fail

    addi s0, x0, 10
    addi t0, x0, -1
    srli t1, t0, 31
    addi t2, x0, 1
    bne  t1, t2, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>