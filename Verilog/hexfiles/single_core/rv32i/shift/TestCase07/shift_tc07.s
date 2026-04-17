<FILE filename="shift_tc07.s" size="4880 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Shift group test for RV32I - TEST CASE 07
    # Extra edge cases: 0xAAAA5555 mix, shift by 31/0
    ####################################################################

    ####################################################################
    # TEST 1: sll 0xAAAA5555 << 1
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0xaaaa5
    addi t0, t0, 0x555
    addi t1, x0, 1
    sll  t2, t0, t1
    lui  t3, 0x5555a
    addi t3, t3, -0xaaa
    bne  t2, t3, fail

    ####################################################################
    # TEST 2-10: more patterns + x0
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0xaaaa5
    addi t0, t0, 0x555
    srli t1, t0, 31
    addi t2, x0, 1
    bne  t1, t2, fail

    addi s0, x0, 3
    lui  t0, 0x80000
    srai t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 4
    addi t0, x0, 0x7fffffff
    slli t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 5
    addi t0, x0, -1
    srli t1, t0, 0
    bne  t1, t0, fail

    addi s0, x0, 6
    addi t0, x0, 1
    sll  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 7
    addi t0, x0, 0x80000000
    sra  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 8
    addi t0, x0, 0x55555555
    slli t1, t0, 31
    lui  t2, 0x80000
    addi t2, t2, -0x80000000
    bne  t1, t2, fail

    addi s0, x0, 9
    addi t0, x0, -1
    srli t1, t0, 31
    addi t2, x0, 1
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