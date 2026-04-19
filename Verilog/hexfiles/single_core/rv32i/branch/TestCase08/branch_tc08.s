<FILE filename="branch_tc08.s" size="4890 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 08
    # Extra edge cases: x0 in branch compare, jalr x0, self-loop
    ####################################################################

    ####################################################################
    # TEST 1: beq x0, x0 taken
    ####################################################################
    addi s0, x0, 1
    beq  x0, x0, test1_ok
    jal  x0, fail
test1_ok:

    ####################################################################
    # TEST 2-10: jalr x0, x0 compare, boundary loops
    ####################################################################
    addi s0, x0, 2
    addi t0, x0, 0
    bne  t0, x0, fail

    addi s0, x0, 3
    addi t0, x0, 1
    blt  x0, t0, test3_ok
    jal  x0, fail
test3_ok:

    addi s0, x0, 4
    addi t0, x0, 0
    bgeu x0, t0, test4_ok
    jal  x0, fail
test4_ok:

    addi s0, x0, 5
    auipc t0, 0
    addi  t0, t0, 8
    jalr  x0, 0(t0)   # no link
    jal   x0, fail
test5_target:
    jal   x0, test5_ok
test5_ok:

    addi s0, x0, 6
    addi t0, x0, 3
    addi t1, x0, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bge  t0, x0, loop6
    addi t2, x0, 3
    bne  t1, t2, fail

    addi s0, x0, 7
    addi t0, x0, -5
    addi t1, x0, 0
loop7:
    addi t1, t1, 1
    addi t0, t0, 1
    blt  t0, x0, loop7
    addi t2, x0, 5
    bne  t1, t2, fail

    addi s0, x0, 8
    addi t0, x0, 0xaaaaaaaa
    addi t1, x0, 0x55555555
    bgeu t0, t1, test8_ok
    jal  x0, fail
test8_ok:

    addi s0, x0, 9
    addi t0, x0, 0x80000000
    addi t1, x0, 0x7fffffff
    blt  t0, t1, test9_ok
    jal  x0, fail
test9_ok:

    addi s0, x0, 10
    addi t0, x0, 0
    addi t1, x0, 0
    bne  t0, t1, fail

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>