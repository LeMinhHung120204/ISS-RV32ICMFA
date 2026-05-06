    .section .text
    .globl _start
    .option norvc
_start:
    ####################################################################
    # RV32A single-core full basic test - TEST CASE 06
    # Extra edge cases: lr/sc failure simulation, heavy x0
    ####################################################################
    la   s1, atomic_mem
    ####################################################################
    # TEST 1-10: lr/sc + AMO with x0 + negative patterns
    ####################################################################
    li s0, 1
    li t0, 0xdeadbeef
    sw   t0, 0(s1)
    lr.w t1, (s1)
    li t2, 0x12345678
    sc.w t3, t2, (s1)
    bne  t3, x0, fail
    li s0, 2
    li t0, -1
    sw   t0, 0(s1)
    li t1, 0xaaaaaaaa
    amoswap.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail
    li s0, 3
    lui  t0, 0x80000
    sw   t0, 0(s1)
    li t1, 1
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    lui  t3, 0x80000
    addi t3, t3, 1
    bne  t2, t3, fail
    li s0, 4
    li t0, 0
    sw   t0, 0(s1)
    li t1, -2048
    amomin.w x0, t1, (s1)
    lw   t2, 0(s1)
    li t3, -2048
    bne  t2, t3, fail
    li s0, 5
    li t0, 1
    sw   t0, 0(s1)
    li t1, -1
    amomaxu.w x0, t1, (s1)
    lw   t2, 0(s1)
    li t3, -1
    bne  t2, t3, fail
    li s0, 6
    li t0, 0x55555555
    sw   t0, 0(s1)
    li t1, 0xaaaaaaaa
    amoxor.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, x0, fail
    li s0, 7
    li t0, 0x7fffffff
    sw   t0, 0(s1)
    li t1, -0x7fffffff
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, x0, fail
    li s0, 8
    li t0, -1
    sw   t0, 0(s1)
    li t1, 1
    amominu.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail
    li s0, 9
    li t0, 123
    sw   t0, 0(s1)
    lr.w t1, (s1)
    li t2, -123
    sc.w t3, t2, (s1)
    bne  t3, x0, fail
    li s0, 10
    li t0, 0
    sw   t0, 0(s1)
    li t1, 0x80000000
    amoor.w x0, t1, (s1)
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
