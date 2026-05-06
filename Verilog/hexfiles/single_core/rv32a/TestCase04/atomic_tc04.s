    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # RV32A single-core full basic test - TEST CASE 04
    # Extra edge cases: wrap-around AMO, negative large values
    ####################################################################
    la   s1, atomic_mem
    ####################################################################
    # TEST 1-10: more AMO with negative / wrap + x0
    ####################################################################
    li s0, 1
    lui  t0, 0x80000
    sw   t0, 0(s1)
    li t1, -1
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    lui  t3, 0x7ffff
    addi t3, t3, -1
    bne  t2, t3, fail
    li s0, 2
    li t0, 0
    sw   t0, 0(s1)
    li t1, -1
    amoswap.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail
    li s0, 3
    li t0, -5
    sw   t0, 0(s1)
    li t1, 3
    amomin.w x0, t1, (s1)
    lw   t2, 0(s1)
    li t3, -5
    bne  t2, t3, fail
    li s0, 4
    li t0, 1
    sw   t0, 0(s1)
    li t1, -1
    amomaxu.w x0, t1, (s1)
    lw   t2, 0(s1)
    li t3, -1
    bne  t2, t3, fail
    li s0, 5
    lr.w t0, (s1)
    li t1, 0x12345678
    sc.w t2, t1, (s1)
    bne  t2, x0, fail
    li s0, 6
    li t0, 0xaaaaaaaa
    sw   t0, 0(s1)
    li t1, 0x55555555
    amoxor.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, x0, fail
    li s0, 7
    li t0, 0x7fffffff
    sw   t0, 0(s1)
    li t1, 1
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    lui  t3, 0x80000
    bne  t2, t3, fail
    li s0, 8
    li t0, -2048
    sw   t0, 0(s1)
    li t1, 2047
    amoand.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, x0, fail
    li s0, 9
    li t0, 0
    sw   t0, 0(s1)
    li t1, 0x80000000
    amoor.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail
    li s0, 10
    li t0, -1
    sw   t0, 0(s1)
    li t1, 0
    amominu.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail
pass:
    li a0, 1
pass_loop:
    jal x0, pass_loop
fail:
    add  a0, s0, x0
fail_loop:
    jal x0, fail_loop
    .section .data
    .align 4
atomic_mem:
    .word 0
