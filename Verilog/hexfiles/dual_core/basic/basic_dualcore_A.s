    .section .text
    .globl _start
    .option norvc

    .equ FLAG_A_DONE,   0x00010000
    .equ FLAG_B_DONE,   0x00010004
    .equ FLAG_A_STEP,   0x00010008
    .equ FLAG_B_STEP,   0x0001000C

    .equ A_RES0,        0x00010010
    .equ A_RES1,        0x00010014
    .equ A_RES2,        0x00010018
    .equ B_RES0,        0x0001001C
    .equ B_RES1,        0x00010020
    .equ B_RES2,        0x00010024

_start:
    # clear A flags/results used by A
    li   t0, FLAG_A_DONE
    sw   x0, 0(t0)
    li   t0, FLAG_A_STEP
    sw   x0, 0(t0)

    ####################################################################
    # TEST A1: add/sub chain
    # (5 + 7) - 3 = 9
    ####################################################################
    li   t0, 5
    li   t1, 7
    add  t2, t0, t1
    li   t3, 3
    sub  t4, t2, t3
    li   t5, 9
    bne  t4, t5, fail
    li   t0, A_RES0
    sw   t4, 0(t0)

    li   t0, FLAG_A_STEP
    li   t1, 1
    sw   t1, 0(t0)

wait_b1:
    li   t0, FLAG_B_STEP
    lw   t1, 0(t0)
    li   t2, 1
    bne  t1, t2, wait_b1

    ####################################################################
    # TEST A2: logical/shift chain
    # ((0x12 << 4) | 0x3) xor 0x5 = 0x126
    ####################################################################
    li   t0, 0x12
    slli t1, t0, 4
    ori  t1, t1, 0x3
    xori t1, t1, 0x5
    li   t2, 0x126
    bne  t1, t2, fail
    li   t0, A_RES1
    sw   t1, 0(t0)

    li   t0, FLAG_A_STEP
    li   t1, 2
    sw   t1, 0(t0)

wait_b2:
    li   t0, FLAG_B_STEP
    lw   t1, 0(t0)
    li   t2, 2
    bne  t1, t2, wait_b2

    ####################################################################
    # TEST A3: branch path check
    ####################################################################
    li   t0, 4
    li   t1, 4
    beq  t0, t1, a3_taken
    jal  x0, fail
a3_taken:
    li   t2, 111
    li   t0, A_RES2
    sw   t2, 0(t0)

    ####################################################################
    # Final cross-check B results
    ####################################################################
    li   t0, B_RES0
    lw   t1, 0(t0)
    li   t2, 5
    bne  t1, t2, fail

    li   t0, B_RES1
    lw   t1, 0(t0)
    li   t2, 1
    bne  t1, t2, fail

    li   t0, B_RES2
    lw   t1, 0(t0)
    li   t2, 222
    bne  t1, t2, fail

    li   t0, FLAG_A_DONE
    li   t1, 1
    sw   t1, 0(t0)

wait_b_done:
    li   t0, FLAG_B_DONE
    lw   t1, 0(t0)
    beq  t1, x0, wait_b_done

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    li   a0, 11
fail_loop:
    jal  x0, fail_loop