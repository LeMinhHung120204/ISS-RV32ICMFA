    .section .text
    .globl _start
    .option norvc

    .equ LOCK_ADDR,     0x00010000
    .equ COUNTER,       0x00010004
    .equ DONE_A,        0x00010008
    .equ DONE_B,        0x0001000C
    .equ SUM_A,         0x00010010
    .equ SUM_B,         0x00010014
    .equ LRSC_CELL,     0x00010018

_start:
    ####################################################################
    # CASE 1: spinlock by amoswap, counter++
    ####################################################################
lock_try_b1:
    li      t0, LOCK_ADDR
    li      t1, 1
    amoswap.w t2, t1, (t0)
    bne     t2, x0, lock_try_b1

    li      t0, COUNTER
    lw      t1, 0(t0)
    addi    t1, t1, 1
    sw      t1, 0(t0)

    li      t0, LOCK_ADDR
    sw      x0, 0(t0)

    ####################################################################
    # CASE 2: amoswap/amo logic check
    ####################################################################
    li      t0, SUM_B
    li      t1, 0x55
    sw      t1, 0(t0)

    li      t2, 0x0f
    amoor.w t3, t2, (t0)   # old must be 0x55, new = 0x5f
    li      t4, 0x55
    bne     t3, t4, fail
    lw      t5, 0(t0)
    li      t6, 0x5f
    bne     t5, t6, fail

    ####################################################################
    # CASE 3: wait A done lr/sc and verify cell updated >= 15
    ####################################################################
wait_a:
    li      t0, DONE_A
    lw      t1, 0(t0)
    beq     t1, x0, wait_a

    li      t0, LRSC_CELL
    lw      t1, 0(t0)
    li      t2, 15
    blt     t1, t2, fail

    li      t0, DONE_B
    li      t1, 1
    sw      t1, 0(t0)

pass:
    li      a0, 1
pass_loop:
    jal     x0, pass_loop

fail:
    li      a0, 32
fail_loop:
    jal     x0, fail_loop