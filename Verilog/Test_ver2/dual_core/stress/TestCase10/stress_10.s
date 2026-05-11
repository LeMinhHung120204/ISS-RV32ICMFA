# Group: stress | TestCase: 10 (TC90)
# Description: Full_System
# Combines Math (Fibonacci), Queue push/pop, and Atomics to stress everything simultaneously.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, global_sum
    la a3, q_data
    la a4, q_head
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Calc Fib(10) = 55
    li t0, 0; li t1, 1; li t2, 10
fib_loop:
    add t3, t0, t1; mv t0, t1; mv t1, t3
    addi t2, t2, -1
    bnez t2, fib_loop
    
    # Push 55 to Queue
    sw t0, 0(a3)
    fence w, w
    li t4, 1; sw t4, 0(a4)
    
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Wait for Queue
2:  lw t1, 0(a4)
    beqz t1, 2b
    fence r, r
    
    # Pop data
    lw t2, 0(a3)
    
    # Atomic Add to global
    amoadd.w zero, t2, (a2)
    
    # Verify 55 made it
    lw t3, 0(a2)
    li t4, 55
    bne t3, t4, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
global_sum:.word 0
.align 6
q_data:    .word 0
.align 6
q_head:    .word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
