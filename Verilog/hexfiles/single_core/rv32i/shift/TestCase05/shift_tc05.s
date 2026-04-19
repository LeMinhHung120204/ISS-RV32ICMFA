<FILE filename="shift_tc05.s" size="4890 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 05
    # Extra edge cases: 0xFFFF0000 pattern, shift by 32
    ####################################################################

    ####################################################################
    # TEST 1: slli 0xFFFF0000 << 16 = 0x00000000
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0xffff0
    slli t1, t0, 16
    bne  t1, x0, fail

    ####################################################################
    # TEST 2-10: srl/sra/srai with 0xFFFF0000
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0xffff0
    srli t1, t0, 16
    lui  t2, 0xffff
    bne  t1, t2, fail

    addi s0, x0, 3
    lui  t0, 0xffff0
    srai t1, t0, 16
    addi t2, x0, -1
    bne  t1, t2, fail

    addi s0, x0, 4
    addi t0, x0, 0xaaaaaaaa
    slli t1, t0, 32
    bne  t1, t0, fail

    addi s0, x0, 5
    addi t0, x0, -1
    srli t1, t0, 32
    bne  t1, t0, fail

    addi s0, x0, 6
    addi t0, x0, 0x80000000
    sra  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 7
    addi t0, x0, 0x55555555
    slli t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 8
    addi t0, x0, 1
    slli t1, t0, 31
    lui  t2, 0x80000
    bne  t1, t2, fail

    addi s0, x0, 9
    addi t0, x0, -1
    srli t1, t0, 31
    addi t2, x0, 1
    bne  t1, t2, fail

    addi s0, x0, 10
    addi t0, x0, -8
    srai t1, t0, 2
    addi t2, x0, -2
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