# Group: benchmark | TestCase: 07
# Description: Pointer Chasing (Linked List) & Null Termination
# Stresses L1 Cache and evaluates Load-to-Use latency over non-contiguous memory.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, node1         # Head
    li t0, 0             # Accumulator

chase_loop:
    lw t1, 0(a0)         # Load Value
    add t0, t0, t1       
    lw a0, 4(a0)         # Load Next Pointer
    bnez a0, chase_loop  

check:
    li t2, 60            # 10 + 20 + 30 = 60
    bne t0, t2, fail
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
node3:.word 30, 0       
node2:.word 20, node3   
node1:.word 10, node2   
