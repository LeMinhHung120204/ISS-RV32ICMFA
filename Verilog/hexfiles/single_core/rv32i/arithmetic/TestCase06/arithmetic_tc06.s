<FILE filename="arithmetic_tc06.s" size="5390 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Arithmetic group test for RV32I - TEST CASE 06
    # Extra edge cases: x0 strict in every op, chained large values
    ####################################################################

    ####################################################################
    # TEST 1-10: heavy x0 + boundary tests
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, 0
    add  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 2
    addi t0, x0, 123
    sub  t1, t0, x0
    bne  t1, t0, fail

    addi s0, x0, 3
    addi x0, x0, -1
    bne  x0, x0, fail

    addi s0, x0, 4
    lui  t0, 0x80000
    addi t1, t0, -1
    addi t2, t1, 1
    bne  t2, t0, fail

    addi s0, x0, 5
    auipc t0, 0
    auipc t1, 0
    addi t0, t0, 12
    bne  t0, t1, fail

    addi s0, x0, 6
    addi t0, x0, 0x7fffffff
    addi t1, t0, 0x7fffffff
    lui  t2, 0x7ffff
    addi t2, t2, -2
    bne  t1, t2, fail

    addi s0, x0, 7
    addi t0, x0, -2048
    addi t1, t0, -2048
    lui  t2, 0xfffff
    addi t2, t2, -4096
    bne  t1, t2, fail

    addi s0, x0, 8
    lui  t0, 0x12345
    addi t0, t0, 0x678
    addi t1, t0, -0x678
    lui  t2, 0x12345
    bne  t1, t2, fail

    addi s0, x0, 9
    auipc t0, 1
    auipc t1, 0
    lui  t2, 0x1
    add  t1, t1, t2
    addi t1, t1, -4
    bne  t0, t1, fail

    addi s0, x0, 10
    addi t0, x0, 0
    addi t1, t0, 2047
    addi t2, t1, 1
    lui  t3, 0x1
    bne  t2, t3, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>