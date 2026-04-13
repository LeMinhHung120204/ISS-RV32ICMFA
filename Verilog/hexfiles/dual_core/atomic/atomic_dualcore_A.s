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
    # init some shared states from A
    li   t0, LOCK_ADDR
    sw   x0, 0(t0)
    li   t0, COUNTER
    sw   x0, 0(t0)
    li   t0, DONE_A
    sw   x0, 0(t0)
    li   t0, DONE_B
    sw   x0, 0(t0)
    li   t0, LRSC_CELL
    li   t1, 10
    sw   t1, 0(t0)

    ####################################################################
    # CASE 1: spinlock by amoswap, counter++
    ####################################################################
lock_try_a1:
    li      t0, LOCK_ADDR
    li      t1, 1
    amoswap.w t2, t1, (t0)
    bne     t2, x0, lock_try_a1

    li      t0, COUNTER
    lw      t1, 0(t0)
    addi    t1, t1, 1
    sw      t1, 0(t0)

    li      t0, LOCK_ADDR
    sw      x0, 0(t0)

    ####################################################################
    # CASE 2: amoadd.w accumulate +3
    ####################################################################
    li      t0, SUM_A
    li      t1, 100
    sw      t1, 0(t0)
    li      t2, 3
    amoadd.w t3, t2, (t0)
    li      t4, 100
    bne     t3, t4, fail
    lw      t5, 0(t0)
    li      t6, 103
    bne     t5, t6, fail

    ####################################################################
    # CASE 3: lr/sc on single location
    ####################################################################
lrsc_retry_a:
    li      t0, LRSC_CELL
    lr.w    t1, (t0)
    addi    t2, t1, 5
    sc.w    t3, t2, (t0)
    bne     t3, x0, lrsc_retry_a

    li      t0, DONE_A
    li      t1, 1
    sw      t1, 0(t0)

wait_b:
    li      t0, DONE_B
    lw      t1, 0(t0)
    beq     t1, x0, wait_b

    ####################################################################
    # Final checks
    ####################################################################
    li      t0, COUNTER
    lw      t1, 0(t0)
    li      t2, 2
    bne     t1, t2, fail

    li      t0, SUM_B
    lw      t1, 0(t0)
    li      t2, 0x5a
    bne     t1, t2, fail

pass:
    li      a0, 1
pass_loop:
    jal     x0, pass_loop

fail:
    li      a0, 31
fail_loop:
    jal     x0, fail_loop