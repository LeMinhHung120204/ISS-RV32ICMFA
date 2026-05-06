# Group: producer_consumer | TestCase: 05 (TC75)
# Description: Fence_Head (FENCE W,W)
# Explicitly tests Write-to-Write ordering to prevent the consumer from seeing garbage.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, q_head
    la a3, q_buffer
    
    beqz t0, producer_core
    li t1, 1
    beq t0, t1, consumer_core
    j park_core

producer_core:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t1, 0x5A5A5A5A
    sw t1, 0(a3)         # 1. Write Payload
    
    # FENCE W,W guarantees that the Payload write is visible globally
    # BEFORE the Head write becomes visible.
    fence w, w
    
    li t1, 1
    sw t1, 0(a2)         # 2. Write Head
    j pass_end

consumer_core:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

1:  lw t1, 0(a2)
    beqz t1, 1b          # Spin on Head
    
    fence r, r           # Prevent early read of payload
    lw t2, 0(a3)         # Read Payload
    
    li t3, 0x5A5A5A5A
    bne t2, t3, fail
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
q_head:      .word 0x0
.align 6
q_buffer:    .word 0x0
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
