<FILE filename="branch_tc03.s" size="5120 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # Branch group test for RV32I - TEST CASE 03
    # Extra edge cases: 0x55555555 / 0xAAAAAAAA patterns, jalr complex
    ####################################################################

    ####################################################################
    # TEST 1: beq with 0x55555555
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    lui  t1, 0x55555
    addi t1, t1, 0x555
    beq  t0, t1, test1_ok
    jal  x0, fail
test1_ok:

    ####################################################################
    # TEST 2: bne with 0xAAAAAAAA
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0xaaaa a
    addi t0, t0, -0x556
    lui  t1, 0xaaaa a
    addi t1, t1, -0x555
    bne  t0, t1, test2_ok
    jal  x0, fail
test2_ok:

    ####################################################################
    # TEST 3: blt signed 0x80000000 < 0x7fffffff taken
    ####################################################################
    addi s0, x0, 3
    lui  t0, 0x80000
    lui  t1, 0x7ffff
    addi t1, t1, -1
    blt  t0, t1, test3_ok
    jal  x0, fail
test3_ok:

    ####################################################################
    # TEST 4-10: more jal/jalr, offset, loop variants
    ####################################################################
    addi s0, x0, 4
    auipc t0, 0
    addi  t0, t0, 16
    jalr  t1, 0(t0)
    jal   x0, fail
    jal   x0, fail
test4_target:
    auipc t2, 0
    addi  t2, t2, -20
    bne   t1, t2, fail

    addi s0, x0, 5
    addi t2, x0, 0
    jal  x0, test5_skip
    addi t2, x0, 99
test5_skip:
    bne  t2, x0, fail

    addi s0, x0, 6
    addi t0, x0, 10
    addi t1, x0, 0
loop6:
    addi t1, t1, 1
    addi t0, t0, -1
    bge  t0, x0, loop6
    addi t2, x0, 10
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
    auipc t0, 0
    addi  t0, t0, 8
    jalr  x0, 0(t0)   # jalr x0 should not write ra
    jal   x0, fail
test8_target2:
    jal   x0, test8_ok
test8_ok:

    addi s0, x0, 9
    addi t0, x0, 0
    addi t1, x0, 0
    beq  t0, t1, test9_ok
    jal  x0, fail
test9_ok:

    addi s0, x0, 10
    addi t0, x0, -1
    addi t1, x0, 0
    bltu t0, t1, fail   # unsigned -1 is max

pass:
    addi a0, x0, 1
pass_loop:
    jal x0, pass_loop

fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
</FILE>