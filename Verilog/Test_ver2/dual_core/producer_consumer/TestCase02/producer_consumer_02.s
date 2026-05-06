# Group: producer_consumer | TestCase: 02 (TC72)
# Description: SPSC_LockFree
# Lock-free queue using independent head and tail indices separated by cache lines.
.section.text
.global _start
_start:
    csrr t0, mhartid
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    la a1, sync_flags
    la a2, q_head
    la a3, q_tail
    la a4, q_buffer
    
    beqz t0, producer_core
    li t1, 1
    beq t0, t1, consumer_core
    j park_core

producer_core:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Produce item
    li t1, 0xCAFEF00D
    sw t1, 0(a4)
    fence w, w           # RVWMO: Ensure data is written before head is updated
    li t1, 1
    sw t1, 0(a2)         # Update Head
    
    j pass_end

consumer_core:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Consume item
1:  lw t1, 0(a2)         # Read Head
    lw t2, 0(a3)         # Read Tail
    beq t1, t2, 1b       # Spin if Head == Tail (Empty)
    
    fence r, r           # RVWMO: Ensure head is read before data
    lw t3, 0(a4)         # Read Data
    
    # Update Tail
    li t2, 1
    sw t2, 0(a3)
    
    li t4, 0xCAFEF00D
    bne t3, t4, fail
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6                 # Padding to prevent false sharing
q_head:      .word 0x0
.align 6
q_tail:      .word 0x0
.align 6
q_buffer:    .word 0x0
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
