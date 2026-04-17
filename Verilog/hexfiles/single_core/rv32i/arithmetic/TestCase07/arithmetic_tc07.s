<FILE filename="arithmetic_tc07.s" size="5570 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 07
    # Extra edge cases: 0x5555AAAA mix, max positive wrap
    ####################################################################

    ####################################################################
    # TEST 1: add 0x5555AAAA + 0xAAAA5555 = 0xFFFFFFFF
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x5555a
    addi t0, t0, 0xaaa
    lui  t1, 0xaaaa5
    addi t1, t1, 0x555
    add  t2, t0, t1
    addi t3, x0, -1
    bne  t2, t3, fail

    ####################################################################
    # TEST 2-10: more overflow, chained, auipc
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0x80000
    addi t0, t0, -1
    addi t1, x0, 2
    add  t2, t0, t1
    lui  t3, 0x80000
    addi t3, t3, 1
    bne  t2, t3, fail

    addi s0, x0, 3
    addi t0, x0, 0x7fffffff
    sub  t1, t0, t0
    bne  t1, x0, fail

    addi s0, x0, 4
    addi t0, x0, -1
    addi t1, t0, -1
    addi t2, t1, -1
    addi t3, x0, -3
    bne  t2, t3, fail

    addi s0, x0, 5
    auipc t0, 0x100
    auipc t1, 0
    lui  t2, 0x100
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    addi s0, x0, 6
    addi t0, x0, 2047
    addi t1, t0, 2047
    addi t2, t1, 2047
    lui  t3, 0x1
    addi t3, t3, 2045
    bne  t2, t3, fail

    addi s0, x0, 7
    addi x0, x0, 0x80000000
    bne  x0, x0, fail

    addi s0, x0, 8
    lui  t0, 0xfffff
    addi t1, t0, 2048
    bne  t1, x0, fail

    addi s0, x0, 9
    addi t0, x0, 0
    addi t1, t0, -1
    sub  t2, t1, t0
    bne  t2, t1, fail

    addi s0, x0, 10
    lui  t0, 0x40000
    add  t1, t0, t0
    lui  t2, 0x80000
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