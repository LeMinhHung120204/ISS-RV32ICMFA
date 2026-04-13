    .section .text
    .globl _start
    .option norvc

    .equ FLAG_A2B,      0x00010000
    .equ FLAG_B2A,      0x00010004
    .equ TEST_ID,       0x00010008

    .equ SHARED_W0,     0x00010010
    .equ SHARED_W1,     0x00010014
    .equ SHARED_B0,     0x00010018
    .equ SHARED_H0,     0x0001001C
    .equ FINAL_STAT,    0x00010020

_start:
    ####################################################################
    # CASE 1: read word from A
    ####################################################################
wait_a1:
    li   t0, FLAG_A2B
    lw   t1, 0(t0)
    li   t2, 1
    bne  t1, t2, wait_a1

    li   t0, SHARED_W0
    lw   t1, 0(t0)
    lui  t2, 0x12345
    addi t2, t2, 0x678
    bne  t1, t2, fail

    li   t0, FLAG_B2A
    li   t1, 1
    sw   t1, 0(t0)

    ####################################################################
    # CASE 2: read byte sign/zero extension
    ####################################################################
wait_a2:
    li   t0, FLAG_A2B
    lw   t1, 0(t0)
    li   t2, 2
    bne  t1, t2, wait_a2

    li   t0, SHARED_B0
    lb   t1, 0(t0)
    li   t2, -1
    bne  t1, t2, fail

    lbu  t1, 0(t0)
    li   t2, 255
    bne  t1, t2, fail

    li   t0, FLAG_B2A
    li   t1, 2
    sw   t1, 0(t0)

    ####################################################################
    # CASE 3: read half sign/zero extension
    ####################################################################
wait_a3:
    li   t0, FLAG_A2B
    lw   t1, 0(t0)
    li   t2, 3
    bne  t1, t2, wait_a3

    li   t0, SHARED_H0
    lh   t1, 0(t0)
    li   t2, -1
    bne  t1, t2, fail

    lhu  t1, 0(t0)
    li   t2, 65535
    bne  t1, t2, fail

    li   t0, FLAG_B2A
    li   t1, 3
    sw   t1, 0(t0)

    ####################################################################
    # CASE 4: overwrite shared word
    ####################################################################
wait_a4:
    li   t0, FLAG_A2B
    lw   t1, 0(t0)
    li   t2, 4
    bne  t1, t2, wait_a4

    li   t0, SHARED_W1
    lw   t1, 0(t0)
    li   t2, 55
    bne  t1, t2, fail

    li   t3, 99
    sw   t3, 0(t0)

    li   t0, FLAG_B2A
    li   t1, 4
    sw   t1, 0(t0)

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    li   a0, 22
fail_loop:
    jal  x0, fail_loop