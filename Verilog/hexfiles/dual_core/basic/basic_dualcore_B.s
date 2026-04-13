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
    li   t0, FLAG_B_DONE
    sw   x0, 0(t0)
    li   t0, FLAG_B_STEP
    sw   x0, 0(t0)

    ####################################################################
    # TEST B1: sub/add chain
    # (9 - 4) + 0 = 5
    ####################################################################
    li   t0, 9
    li   t1, 4
    sub  t2, t0, t1
    addi t2, t2, 0
    li   t3, 5
    bne  t2, t3, fail
    li   t0, B_RES0
    sw   t2, 0(t0)

    li   t0, FLAG_B_STEP
    li   t1, 1
    sw   t1, 0(t0)

wait_a1:
    li   t0, FLAG_A_STEP
    lw   t1, 0(t0)
    li   t2, 1
    bne  t1, t2, wait_a1

    ####################################################################
    # TEST B2: compare
    # slt 3 < 7 => 1
    ####################################################################
    li   t0, 3
    li   t1, 7
    slt  t2, t0, t1
    li   t3, 1
    bne  t2, t3, fail
    li   t0, B_RES1
    sw   t2, 0(t0)

    li   t0, FLAG_B_STEP
    li   t1, 2
    sw   t1, 0(t0)

wait_a2:
    li   t0, FLAG_A_STEP
    lw   t1, 0(t0)
    li   t2, 2
    bne  t1, t2, wait_a2

    ####################################################################
    # TEST B3: branch path check
    ####################################################################
    li   t0, 5
    li   t1, 6
    bne  t0, t1, b3_taken
    jal  x0, fail
b3_taken:
    li   t2, 222
    li   t0, B_RES2
    sw   t2, 0(t0)

    ####################################################################
    # Final cross-check A results
    ####################################################################
    li   t0, A_RES0
    lw   t1, 0(t0)
    li   t2, 9
    bne  t1, t2, fail

    li   t0, A_RES1
    lw   t1, 0(t0)
    li   t2, 0x126
    bne  t1, t2, fail

    li   t0, A_RES2
    lw   t1, 0(t0)
    li   t2, 111
    bne  t1, t2, fail

    li   t0, FLAG_B_DONE
    li   t1, 1
    sw   t1, 0(t0)

wait_a_done:
    li   t0, FLAG_A_DONE
    lw   t1, 0(t0)
    beq  t1, x0, wait_a_done

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    li   a0, 12
fail_loop:
    jal  x0, fail_loop