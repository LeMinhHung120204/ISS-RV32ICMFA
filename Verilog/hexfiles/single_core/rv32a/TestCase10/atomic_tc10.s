<FILE filename="atomic_tc10.s" size="7310 bytes">
    .section .text
    .globl _start
    .option norvc

_start:
    ####################################################################
    # RV32A single-core full basic test - TEST CASE 10 (FINAL)
    # Comprehensive mix of all AMO + lr/sc + x0 + edge cases
    ####################################################################

    la   s1, atomic_mem

    ####################################################################
    # TEST 1-10: final full coverage of every instruction + boundary
    ####################################################################
    addi s0, x0, 1
    addi t0, x0, 0x55555555
    sw   t0, 0(s1)
    addi t1, x0, 0xaaaaaaaa
    amoxor.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, x0, fail

    addi s0, x0, 2
    lui  t0, 0x80000
    sw   t0, 0(s1)
    addi t1, x0, 1
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    lui  t3, 0x80000
    addi t3, t3, 1
    bne  t2, t3, fail

    addi s0, x0, 3
    addi t0, x0, -1
    sw   t0, 0(s1)
    addi t1, x0, 1
    amominu.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 4
    addi t0, x0, 0x7fffffff
    sw   t0, 0(s1)
    addi t1, x0, -1
    amoadd.w x0, t1, (s1)
    lw   t2, 0(s1)
    lui  t3, 0x7ffff
    addi t3, t3, -2
    bne  t2, t3, fail

    addi s0, x0, 5
    addi t0, x0, -5
    sw   t0, 0(s1)
    addi t1, x0, 3
    amomax.w x0, t1, (s1)
    lw   t2, 0(s1)
    addi t3, x0, 3
    bne  t2, t3, fail

    addi s0, x0, 6
    lr.w t0, (s1)
    addi t1, x0, 0x12345678
    sc.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 7
    addi t0, x0, 0
    sw   t0, 0(s1)
    addi t1, x0, 0x80000000
    amoor.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 8
    addi t0, x0, 0xaaaaaaaa
    sw   t0, 0(s1)
    addi t1, x0, 0x55555555
    amoswap.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t1, fail

    addi s0, x0, 9
    addi t0, x0, -2048
    sw   t0, 0(s1)
    addi t1, x0, 2048
    amoand.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, x0, fail

    addi s0, x0, 10
    addi t0, x0, -1
    sw   t0, 0(s1)
    addi t1, x0, -1
    amomin.w x0, t1, (s1)
    lw   t2, 0(s1)
    bne  t2, t0, fail

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