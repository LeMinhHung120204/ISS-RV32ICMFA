<FILE filename="branch_tc09.s" size="5080 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 09
    # Extra edge cases: heavy jalr offset, mixed signed/unsigned
    ####################################################################

    ####################################################################
    # TEST 1-10: jalr with large negative/positive offset
    ####################################################################
    addi s0, x0, 1
    auipc t0, 0
    addi  t0, t0, 32
    jalr  t1, -28(t0)
    jal   x0, fail
test1_target:
    auipc t2, 0
    addi  t2, t2, -36
    bne   t1, t2, fail

    addi s0, x0, 2
    addi t0, x0, 0x7fffffff
    addi t1, x0, 0
    bge  t0, t1, test2_ok
    jal  x0, fail
test2_ok:

    addi s0, x0, 3
    addi t0, x0, -1
    addi t1, x0, 0
    bltu t1, t0, test3_ok
    jal  x0, fail
test3_ok:

    addi s0, x0, 4
    addi t2, x0, 0
    jal  x0, test4_skip
    addi t2, x0, 99
test4_skip:
    bne  t2, x0, fail

    addi s0, x0, 5
    addi t0, x0, 0
    addi t1, x0, -2048
    blt  t1, t0, test5_ok
    jal  x0, fail
test5_ok:

    addi s0, x0, 6
    addi t0, x0, 5
    addi t1, x0, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop6
    addi t2, x0, 5
    bne  t1, t2, fail

    addi s0, x0, 7
    addi t0, x0, 0xaaaaaaaa
    addi t1, x0, 0xaaaaaaaa
    beq  t0, t1, test7_ok
    jal  x0, fail
test7_ok:

    addi s0, x0, 8
    addi t0, x0, 0x55555555
    addi t1, x0, 0x55555555
    bne  t0, t1, fail

    addi s0, x0, 9
    auipc t0, 0
    addi  t0, t0, 12
    jalr  t1, 0(t0)
    jal   x0, fail
test9_target:
    auipc t2, 0
    addi  t2, t2, -16
    bne   t1, t2, fail

    addi s0, x0, 10
    addi t0, x0, 0x80000000
    addi t1, x0, 0x80000000
    bge  t0, t1, test10_ok
    jal  x0, fail
test10_ok:

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>