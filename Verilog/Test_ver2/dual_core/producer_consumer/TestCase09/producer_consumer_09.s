# Group: producer_consumer | TestCase: 09 (TC79)
# Description: Wrap_Around
# Tests Ring Buffer bounds checking and pointer wrap-around (Modulo arithmetic).
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

    li t0, 10            # Loop 10 times (Wrap occurs every 4 times)
1:  lw t1, 0(a2)         # Head
    lw t2, 0(a3)         # Tail
    addi t3, t1, 1
    andi t3, t3, 3       # Next_Head = (Head + 1) % 4
    beq t3, t2, 1b       # Spin if Full (Next_Head == Tail)
    
    sw t3, 0(a2)         # Update Head
    addi t0, t0, -1
    bnez t0, 1b
    j pass_end

consumer_core:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 10
1:  lw t1, 0(a2)         # Head
    lw t2, 0(a3)         # Tail
    beq t1, t2, 1b       # Spin if Empty
    
    addi t2, t2, 1
    andi t2, t2, 3       # Next_Tail = (Tail + 1) % 4
    sw t2, 0(a3)         # Update Tail
    
    addi t0, t0, -1
    bnez t0, 1b
    
    # Final state check (after 10 ops modulo 4): Head should be 2
    li t3, 2
    bne t1, t3, fail

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
