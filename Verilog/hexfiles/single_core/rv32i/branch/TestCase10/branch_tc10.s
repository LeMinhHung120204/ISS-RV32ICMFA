<FILE filename="branch_tc10.s" size="5210 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 10 (FINAL)
    # Comprehensive mix of all branch instructions + edge cases
    ####################################################################

    ####################################################################
    # TEST 1-10: full coverage of beq/bne/blt/bge/bltu/bgeu/jal/jalr
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, 0x55555555
    addi t1, x0, 0xaaaaaaaa
    bne  t0, t1, test1_ok
    jal  x0, fail
test1_ok:

    addi s0, x0, 2
    lui  t0, 0x80000
    addi t1, x0, 0
    blt  t0, t1, test2_ok
    jal  x0, fail
test2_ok:

    addi s0, x0, 3
    addi t0, x0, -1
    addi t1, x0, 1
    bgeu t0, t1, test3_ok
    jal  x0, fail
test3_ok:

    addi s0, x0, 4
    addi t2, x0, 0
    jal  x0, test4_skip
    addi t2, x0, 1
test4_skip:
    bne  t2, x0, fail

    addi s0, x0, 5
    auipc t0, 0
    addi  t0, t0, 24
    jalr  t1, -20(t0)
    jal   x0, fail
test5_target:
    auipc t2, 0
    addi  t2, t2, -28
    bne   t1, t2, fail

    addi s0, x0, 6
    addi t0, x0, 10
    addi t1, x0, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bne  t0, x0, loop6
    addi t2, x0, 10
    bne  t1, t2, fail

    addi s0, x0, 7
    addi t0, x0, 0
    addi t1, x0, 0
    beq  t0, t1, test7_ok
    jal  x0, fail
test7_ok:

    addi s0, x0, 8
    addi t0, x0, 0x7fffffff
    addi t1, x0, 0x80000000
    blt  t0, t1, test8_ok
    jal  x0, fail
test8_ok:

    addi s0, x0, 9
    addi t0, x0, -1
    addi t1, x0, -1
    bge  t0, t1, test9_ok
    jal  x0, fail
test9_ok:

    addi s0, x0, 10
    addi t0, x0, 0
    addi t1, x0, -1
    bltu t0, t1, test10_ok
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