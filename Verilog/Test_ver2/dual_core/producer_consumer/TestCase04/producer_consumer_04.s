# Group: producer_consumer | TestCase: 04 (TC74)
# Description: Full_Spin
# Forces the Producer to spin heavily waiting for the Consumer (Full Queue scenario).
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024
    mul t1, t0, t1
    add sp, sp, t1
    la a1, sync_flags
    la a2, q_state       # 0: Empty, 1: Full
    
    beqz t0, producer_core
    li t1, 1
    beq t0, t1, consumer_core
    j park_core

producer_core:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    # Fill the queue
    li t1, 1
    sw t1, 0(a2)         # State = Full

    # Attempt to push again, must spin until Consumer empties it
1:  lw t2, 0(a2)
    bnez t2, 1b          # Spin while Full
    
    j pass_end

consumer_core:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    # Delay to let Producer get stuck in Full_Spin
    li t0, 2000
delay: addi t0, t0, -1
    bnez t0, delay

    # Empty the queue
    sw zero, 0(a2)       # State = Empty
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
q_state:     .word 0x0
sync_flags:  .word 0x0, 0x0
system_stacks:.skip 2048
