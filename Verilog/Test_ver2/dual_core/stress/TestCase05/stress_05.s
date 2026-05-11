# Group: stress | TestCase: 05 (TC85)
# Description: Branch_Stress
# Executes highly unpredictable branch patterns to stress the Branch Predictor.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    bnez t0, park_core

core0_main:
    li t0, 0             # i = 0
    li t1, 100           # limit
    li t2, 0             # accumulator

loop_start:
    bge t0, t1, loop_end # Predictable
    
    # Parity check (pseudo-random branching)
    andi t3, t0, 1       
    beqz t3, even_branch # 50% Taken, 50% Not Taken
    
odd_branch:
    addi t2, t2, 3
    j merge
    
even_branch:
    addi t2, t2, 5
    
merge:
    # Modulo 3 check
    li t4, 3
    rem t5, t0, t4
    bne t5, zero, skip   # 66% Taken, 33% Not Taken
    addi t2, t2, -1
    
skip:
    addi t0, t0, 1
    j loop_start

loop_end:
    # Manual calculation:
    # 50 evens (+5) = 250
    # 50 odds (+3) = 150. Total = 400
    # Modulo 3 occurs 34 times. 400 - 34 = 366.
    li t6, 366
    bne t2, t6, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
system_stacks:.skip 2048
