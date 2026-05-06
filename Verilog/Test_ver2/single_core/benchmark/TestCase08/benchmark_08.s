# Group: benchmark | TestCase: 08
# Description: Vector Addition & Negative Values
# Tests continuous memory bandwidth and signed arithmetic.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, vecA
    la a1, vecB
    la a2, vecC
    li t0, 4             # Array size

add_loop:
    lw t1, 0(a0)
    lw t2, 0(a1)
    add t3, t1, t2
    sw t3, 0(a2)
    
    addi a0, a0, 4
    addi a1, a1, 4
    addi a2, a2, 4
    addi t0, t0, -1
    bnez t0, add_loop

check:
    la a2, vecC
    lw t1, 12(a2)        # Last element: 40 + (-10) = 30
    li t2, 30
    bne t1, t2, fail
    
    lw t1, 0(a2)         # First element: 10 + (-1) = 9
    li t2, 9
    bne t1, t2, fail

pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core

.section.data
.align 4
vecA:.word 10, 20, 30, 40
vecB:.word -1, -2, -5, -10
vecC:.space 16
