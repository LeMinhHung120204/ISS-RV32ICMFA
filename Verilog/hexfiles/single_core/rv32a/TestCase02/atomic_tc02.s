<FILE filename="atomic_tc02.s" size="7120 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # RV32A single-core full basic test - TEST CASE 02
    # Extra edge cases: 0x55555555 / 0xAAAAAAAA patterns, x0 destination
    ####################################################################

    la   s1, atomic_mem

    ####################################################################
    # TEST 1: lr.w + sc.w with 0x55555555
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x55555
    addi t0, t0, 0x555
    sw   t0, 0(s1)
    lr.w t1, (s1)
    addi t2, x0, 0xAAAAAAAA
    sc.w t3, t2, (s1)
    bne  t3, x0, fail
    lw   t4, 0(s1)
    bne  t4, t2, fail

    ####################################################################
    # TEST 2: amoswap.w with 0xAAAAAAAA
    ####################################################################
    addi s0, x0, 2
    lui  t0, 0xaaaa a
    addi t0, t0, -0x556
    sw   t0, 0(s1)
    lui  t1, 0x55555
    addi t1, t1, 0x555
    amoswap.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    bne  t3, t1, fail

    ####################################################################
    # TEST 3: amoadd.w wraparound 0x7fffffff + 1
    ####################################################################
    addi s0, x0, 3
    lui  t0, 0x80000
    addi t0, t0, -1
    sw   t0, 0(s1)
    addi t1, x0, 1
    amoadd.w t2, t1, (s1)
    bne  t2, t0, fail
    lui  t3, 0x80000
    lw   t4, 0(s1)
    bne  t4, t3, fail

    ####################################################################
    # TEST 4-10: x0 destination, negative values, lr/sc failure simulation
    ####################################################################
    addi s0, x0, 4
    addi t0, x0, 0x55555555
    sw   t0, 0(s1)
    addi t1, x0, 0xAAAAAAAA
    amoand.w x0, t1, (s1)   # x0 destination discarded
    lw   t2, 0(s1)
    and  t3, t0, t1
    bne  t2, t3, fail

    addi s0, x0, 5
    addi t0, x0, -5
    sw   t0, 0(s1)
    addi t1, x0, 3
    amomax.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    addi t4, x0, 3
    bne  t3, t4, fail

    addi s0, x0, 6
    addi t0, x0, -1
    sw   t0, 0(s1)
    addi t1, x0, 1
    amominu.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    bne  t3, t1, fail

    addi s0, x0, 7
    addi t0, x0, 20
    sw   t0, 0(s1)
    addi t1, x0, -10
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    addi t3, x0, 10
    bne  t2, t3, fail

    addi s0, x0, 8
    lr.w t0, (s1)
    addi t1, x0, 0x55555555
    sc.w t2, t1, (s1)
    bne  t2, x0, fail

    addi s0, x0, 9
    auipc t0, 0
    addi t0, t0, 8
    jalr x0, 0(t0)   # dummy to keep alignment

    addi s0, x0, 10
    addi t0, x0, -1
    sw   t0, 0(s1)
    addi t1, x0, -1
    amoxor.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    bne  t3, x0, fail

pass:
    addi a0, x0, 1
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
</FILE>