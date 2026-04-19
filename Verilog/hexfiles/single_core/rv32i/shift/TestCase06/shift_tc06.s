<FILE filename="shift_tc06.s" size="4950 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 06
    # Extra edge cases: x0 strict in every shift, chained shifts
    ####################################################################

    ####################################################################
    # TEST 1-10: x0 heavy + chained shift
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, 1
    sll  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 2
    addi t0, x0, 0x80000000
    sra  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 3
    addi t0, x0, 0xaaaaaaaa
    slli t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 4
    addi t0, x0, -1
    srli t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 5
    addi t0, x0, -5
    srai t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 6
    addi t0, x0, 1
    slli t1, t0, 31
    lui  t2, 0x80000
    bne  t1, t2, fail

    addi s0, x0, 7
    addi t0, x0, 0x7fffffff
    srli t1, t0, 31
    addi t2, x0, 0
    bne  t1, t2, fail

    addi s0, x0, 8
    addi t0, x0, 0x80000000
    srai t1, t0, 31
    addi t2, x0, -1
    bne  t1, t2, fail

    addi s0, x0, 9
    addi t0, x0, 0x55555555
    sll  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 10
    addi t0, x0, 0xaaaaaaaa
    srl  t1, t0, x0
    bne  t1, t0, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>