<FILE filename="shift_tc03.s" size="4920 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 03
    # Extra edge cases: shift by 31/32, signed max/min, x0 strict
    ####################################################################

    ####################################################################
    # TEST 1: slli 0xFFFFFFFF << 31 = 0x80000000
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, -1
    slli t1, t0, 31
    lui  t2, 0x80000
    bne  t1, t2, fail

    ####################################################################
    # TEST 2: srli 0x80000000 >> 31 = 1
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0x80000
    srli t1, t0, 31
    addi t2, x0, 1
    bne  t1, t2, fail

    ####################################################################
    # TEST 3: srai 0x80000000 >> 31 = 0xFFFFFFFF
    ####################################################################
    addi s0, x0, 3
    lui  t0, 0x80000
    srai t1, t0, 31
    addi t2, x0, -1
    bne  t1, t2, fail

    ####################################################################
    # TEST 4-10: shamt edge + x0 + chained
    ####################################################################
    addi s0, x0, 4
    addi t0, x0, 0x55555555
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
    addi t0, x0, 1
    sll  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 8
    addi t0, x0, 0x7fffffff
    slli t1, t0, 1
    lui  t2, 0x80000
    addi t2, t2, -1
    bne  t1, t2, fail

    addi s0, x0, 9
    addi t0, x0, -1
    srli t1, t0, 1
    lui  t2, 0x80000
    addi t2, t2, -1
    bne  t1, t2, fail

    addi s0, x0, 10
    addi t0, x0, -8
    srai t1, t0, 3
    addi t2, x0, -1
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