# Group: producer_consumer | TestCase: 10 (TC80)
# Description: MPMC_Dual (Cross-Queue)
# Core 0 produces to Q1 and consumes from Q2. Core 1 produces to Q2 and consumes Q1.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, q1_head
    la a3, q1_tail
    la a4, q2_head
    la a5, q2_tail
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Produce to Q1
    li t1, 1
    sw t1, 0(a2)         # Set Q1 Head = 1
    
    # Consume from Q2
2:  lw t2, 0(a4)         # Read Q2 Head
    lw t3, 0(a5)         # Read Q2 Tail
    beq t2, t3, 2b       # Spin if Q2 empty
    
    # Acknowledge Q2
    li t3, 1
    sw t3, 0(a5)         # Set Q2 Tail = 1
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Produce to Q2
    li t1, 1
    sw t1, 0(a4)         # Set Q2 Head = 1
    
    # Consume from Q1
2:  lw t2, 0(a2)         # Read Q1 Head
    lw t3, 0(a3)         # Read Q1 Tail
    beq t2, t3, 2b       # Spin if Q1 empty
    
    # Acknowledge Q1
    li t3, 1
    sw t3, 0(a3)         # Set Q1 Tail = 1
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
q1_head:     .word 0x0
.align 6
q1_tail:     .word 0x0
.align 6
q2_head:     .word 0x0
.align 6
q2_tail:     .word 0x0
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
