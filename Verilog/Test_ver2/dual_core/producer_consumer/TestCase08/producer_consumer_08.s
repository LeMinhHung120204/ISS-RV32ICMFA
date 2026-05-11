# Group: producer_consumer | TestCase: 08 (TC78)
# Description: Fast_Cons (Fast Consumer)
# Consumer continuously polls causing frequent Snoop Hits on Producer's cache.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, q_head
    la a3, q_tail
    
    beqz t0, producer_core
    li t1, 1
    beq t0, t1, consumer_core
    j park_core

producer_core:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 5             # Push 5 items slowly
1:  li t3, 1000
    delay: addi t3, t3, -1; bnez t3, delay
    
    lw t1, 0(a2)
    addi t1, t1, 1
    sw t1, 0(a2)         # Update head
    
    addi t0, t0, -1
    bnez t0, 1b
    j pass_end

consumer_core:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 5
1:  lw t1, 0(a2)         # Read head
    lw t2, 0(a3)         # Read tail
    beq t1, t2, 1b       # Fast spin
    
    addi t2, t2, 1
    sw t2, 0(a3)         # Update tail
    
    addi t0, t0, -1
    bnez t0, 1b
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
q_head:      .word 0x0
.align 6
q_tail:      .word 0x0
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
