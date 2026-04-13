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
    # init
    li   t0, FLAG_A2B
    sw   x0, 0(t0)
    li   t0, FLAG_B2A
    sw   x0, 0(t0)
    li   t0, FINAL_STAT
    sw   x0, 0(t0)

    ####################################################################
    # CASE 1: A writes full word, B reads
    ####################################################################
    li   t0, SHARED_W0
    lui  t1, 0x12345
    addi t1, t1, 0x678
    sw   t1, 0(t0)

    li   t0, TEST_ID
    li   t1, 1
    sw   t1, 0(t0)

    li   t0, FLAG_A2B
    li   t1, 1
    sw   t1, 0(t0)

wait_b1:
    li   t0, FLAG_B2A
    lw   t1, 0(t0)
    li   t2, 1
    bne  t1, t2, wait_b1

    ####################################################################
    # CASE 2: A writes byte pattern, B checks lb/lbu
    ####################################################################
    li   t0, SHARED_B0
    li   t1, -1
    sb   t1, 0(t0)

    li   t0, TEST_ID
    li   t1, 2
    sw   t1, 0(t0)

    li   t0, FLAG_A2B
    li   t1, 2
    sw   t1, 0(t0)

wait_b2:
    li   t0, FLAG_B2A
    lw   t1, 0(t0)
    li   t2, 2
    bne  t1, t2, wait_b2

    ####################################################################
    # CASE 3: A writes halfword pattern, B checks lh/lhu
    ####################################################################
    li   t0, SHARED_H0
    li   t1, -1
    sh   t1, 0(t0)

    li   t0, TEST_ID
    li   t1, 3
    sw   t1, 0(t0)

    li   t0, FLAG_A2B
    li   t1, 3
    sw   t1, 0(t0)

wait_b3:
    li   t0, FLAG_B2A
    lw   t1, 0(t0)
    li   t2, 3
    bne  t1, t2, wait_b3

    ####################################################################
    # CASE 4: ping-pong word overwrite
    ####################################################################
    li   t0, SHARED_W1
    li   t1, 55
    sw   t1, 0(t0)

    li   t0, TEST_ID
    li   t1, 4
    sw   t1, 0(t0)

    li   t0, FLAG_A2B
    li   t1, 4
    sw   t1, 0(t0)

wait_b4:
    li   t0, FLAG_B2A
    lw   t1, 0(t0)
    li   t2, 4
    bne  t1, t2, wait_b4

    # B phải overwrite thành 99
    li   t0, SHARED_W1
    lw   t1, 0(t0)
    li   t2, 99
    bne  t1, t2, fail

    li   t0, FINAL_STAT
    li   t1, 1
    sw   t1, 0(t0)

pass:
    li   a0, 1
pass_loop:
    jal  x0, pass_loop

fail:
    li   a0, 21
fail_loop:
    jal  x0, fail_loop