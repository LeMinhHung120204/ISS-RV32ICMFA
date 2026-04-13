    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # RV32A single-core full basic test
    #
    # Tested instructions:
    #   lr.w, sc.w
    #   amoswap.w, amoadd.w, amoxor.w, amoand.w, amoor.w
    #   amomin.w, amomax.w, amominu.w, amomaxu.w
    #
    # Convention:
    #   s0 = current test ID
    #   pass -> a0 = 1, loop forever
    #   fail -> a0 = failed test ID, loop forever
    ####################################################################

    la   s1, atomic_mem

    ####################################################################
    # TEST 1: lr.w reads initial value
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x11223
    addi t0, t0, 0x344
    sw   t0, 0(s1)
    lr.w t1, (s1)
    bne  t1, t0, fail

    ####################################################################
    # TEST 2: sc.w succeeds after lr.w on single core
    # memory: 5 -> 9
    # sc.w rd = 0 on success
    ####################################################################
    addi s0, x0, 2
    addi t0, x0, 5
    sw   t0, 0(s1)
    lr.w t1, (s1)
    addi t2, x0, 9
    sc.w t3, t2, (s1)
    bne  t3, x0, fail
    lw   t4, 0(s1)
    bne  t4, t2, fail

    ####################################################################
    # TEST 3: amoswap.w
    # old=7, new=11, memory becomes 11, rd gets 7
    ####################################################################
    addi s0, x0, 3
    addi t0, x0, 7
    sw   t0, 0(s1)
    addi t1, x0, 11
    amoswap.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    bne  t3, t1, fail

    ####################################################################
    # TEST 4: amoadd.w
    # old=10, add=3 => new=13, rd gets 10
    ####################################################################
    addi s0, x0, 4
    addi t0, x0, 10
    sw   t0, 0(s1)
    addi t1, x0, 3
    amoadd.w t2, t1, (s1)
    bne  t2, t0, fail
    addi t3, x0, 13
    lw   t4, 0(s1)
    bne  t4, t3, fail

    ####################################################################
    # TEST 5: amoxor.w
    # 0x55aa55aa xor 0x0f0f0f0f
    ####################################################################
    addi s0, x0, 5
    lui  t0, 0x55aa5
    addi t0, t0, 0x5aa
    sw   t0, 0(s1)
    lui  t1, 0x0f0f0
    addi t1, t1, 0x0f
    amoxor.w t2, t1, (s1)
    bne  t2, t0, fail
    xor  t3, t0, t1
    lw   t4, 0(s1)
    bne  t4, t3, fail

    ####################################################################
    # TEST 6: amoand.w
    ####################################################################
    addi s0, x0, 6
    lui  t0, 0xffff0
    addi t0, t0, 0x0ff
    sw   t0, 0(s1)
    lui  t1, 0x0ff00
    addi t1, t1, -1
    amoand.w t2, t1, (s1)
    bne  t2, t0, fail
    and  t3, t0, t1
    lw   t4, 0(s1)
    bne  t4, t3, fail

    ####################################################################
    # TEST 7: amoor.w
    ####################################################################
    addi s0, x0, 7
    lui  t0, 0x12340
    addi t0, t0, 0x056
    sw   t0, 0(s1)
    lui  t1, 0x0000f
    addi t1, t1, 0x789
    amoor.w t2, t1, (s1)
    bne  t2, t0, fail
    or   t3, t0, t1
    lw   t4, 0(s1)
    bne  t4, t3, fail

    ####################################################################
    # TEST 8: amomin.w signed
    # min(-5, 3) = -5
    # rd gets old value
    ####################################################################
    addi s0, x0, 8
    addi t0, x0, 3
    sw   t0, 0(s1)
    addi t1, x0, -5
    amomin.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    addi t4, x0, -5
    bne  t3, t4, fail

    ####################################################################
    # TEST 9: amomax.w signed
    # max(-5, 3) = 3
    ####################################################################
    addi s0, x0, 9
    addi t0, x0, -5
    sw   t0, 0(s1)
    addi t1, x0, 3
    amomax.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    addi t4, x0, 3
    bne  t3, t4, fail

    ####################################################################
    # TEST 10: amominu.w unsigned
    # min_u(0xffffffff, 1) = 1
    ####################################################################
    addi s0, x0, 10
    addi t0, x0, -1
    sw   t0, 0(s1)
    addi t1, x0, 1
    amominu.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    bne  t3, t1, fail

    ####################################################################
    # TEST 11: amomaxu.w unsigned
    # max_u(0xffffffff, 1) = 0xffffffff
    ####################################################################
    addi s0, x0, 11
    addi t0, x0, 1
    sw   t0, 0(s1)
    addi t1, x0, -1
    amomaxu.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    addi t4, x0, -1
    bne  t3, t4, fail

    ####################################################################
    # TEST 12: lr/sc round-trip with negative value
    ####################################################################
    addi s0, x0, 12
    addi t0, x0, 12
    sw   t0, 0(s1)
    lr.w t1, (s1)
    addi t2, x0, -8
    sc.w t3, t2, (s1)
    bne  t3, x0, fail
    lw   t4, 0(s1)
    bne  t4, t2, fail

    ####################################################################
    # TEST 13: amoadd.w wraparound
    # 0x7fffffff + 1 = 0x80000000
    ####################################################################
    addi s0, x0, 13
    lui  t0, 0x80000
    addi t0, t0, -1          # 0x7fffffff
    sw   t0, 0(s1)
    addi t1, x0, 1
    amoadd.w t2, t1, (s1)
    bne  t2, t0, fail
    lui  t3, 0x80000         # 0x80000000
    lw   t4, 0(s1)
    bne  t4, t3, fail

    ####################################################################
    # TEST 14: x0 as destination is discarded, memory still updates
    ####################################################################
    addi s0, x0, 14
    addi t0, x0, 20
    sw   t0, 0(s1)
    addi t1, x0, 2
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    addi t3, x0, 22
    bne  t2, t3, fail

    ####################################################################
    # TEST 15: amoswap.w with negative value
    ####################################################################
    addi s0, x0, 15
    addi t0, x0, 6
    sw   t0, 0(s1)
    addi t1, x0, -3
    amoswap.w t2, t1, (s1)
    bne  t2, t0, fail
    lw   t3, 0(s1)
    bne  t3, t1, fail

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