<FILE filename="atomic_tc09.s" size="7150 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # RV32A single-core full basic test - TEST CASE 09
    # Extra edge cases: auipc dummy + AMO x0 + all boundary
    ####################################################################

    la   s1, atomic_mem

    ####################################################################
    # TEST 1-10: full boundary + x0 + lr/sc mix
    ####################################################################
    addi s0, x0, 1
    lui  t0, 0x80000
    sw   t0, 0(s1)
    addi t1, x0, -1
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    lui  t3, 0x7ffff
    addi t3, t3, -1
    bne  t2, t3, fail

    addi s0, x0, 2
    addi t0, x0, -2048
    sw   t0, 0(s1)
    addi t1, x0, 2048
    amomin.w x0, t1, (s1)
    lw   t2, 0(s1)
    addi t3, x0, -2048
    bne  t2, t3, fail

    addi s0, x0, 3
    addi t0, x0, 1
    sw   t0, 0(s1)
    addi t1, x0, -1
    amomaxu.w x0, t1, (s1)
    lw   t2, 0(s1)
    addi t3, x0, -1
    bne  t2, t3, fail

    addi s0, x0, 4
    lr.w t0, (s1)
    addi t1, x0, 0xdeadbeef
    sc.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 5
    addi t0, x0, 0xaaaaaaaa
    sw   t0, 0(s1)
    addi t1, x0, 0x55555555
    amoxor.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, x0, fail

    addi s0, x0, 6
    addi t0, x0, 0
    sw   t0, 0(s1)
    addi t1, x0, 0x80000000
    amoor.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 7
    addi t0, x0, -1
    sw   t0, 0(s1)
    addi t1, x0, 1
    amominu.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 8
    addi t0, x0, 0x55555555
    sw   t0, 0(s1)
    addi t1, x0, 0xaaaaaaaa
    amoswap.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 9
    addi t0, x0, 0x7fffffff
    sw   t0, 0(s1)
    addi t1, x0, -1
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    lui  t3, 0x7ffff
    addi t3, t3, -2
    bne  t2, t3, fail

    addi s0, x0, 10
    addi t0, x0, -5
    sw   t0, 0(s1)
    addi t1, x0, 3
    amomax.w x0, t1, (s1)
    lw   t2, 0(s1)
    addi t3, x0, 3
    bne  t2, t3, fail

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