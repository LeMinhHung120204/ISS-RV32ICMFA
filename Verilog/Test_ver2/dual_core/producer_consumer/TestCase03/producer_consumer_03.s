# Group: producer_consumer | TestCase: 03 (TC73)
# Description: Empty_Spin
# Forces the Consumer to spin heavily waiting for the Producer (Empty Queue scenario).
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
    la a4, q_buffer
    
    beqz t0, producer_core
    li t1, 1
    beq t0, t1, consumer_core
    j park_core

producer_core:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Artificial Delay to force consumer to spin
    li t0, 2000
delay: addi t0, t0, -1
    bnez t0, delay

    li t1, 0x99999999
    sw t1, 0(a4)
    fence w, w
    li t1, 1
    sw t1, 0(a2)
    j pass_end

consumer_core:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Consumer immediately starts spinning
1:  lw t1, 0(a2)
    beqz t1, 1b          # Spin heavily on Head == 0
    
    fence r, r
    lw t3, 0(a4)
    li t4, 0x99999999
    bne t3, t4, fail
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
