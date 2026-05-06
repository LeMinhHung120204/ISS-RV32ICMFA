# Group: synchronization | TestCase: 10 (TC60)
# Description: Ticket_Lock
# A fair spinlock using atomic add to guarantee FIFO ordering and prevent starvation.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, next_ticket
    la a3, now_serving
    la a4, shared_counter
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 50
acquire_loop:
    # 1. Get Ticket (Atomic Add)
    li t1, 1
    amoadd.w t2, t1, (a2)  # t2 holds my ticket number
    
    # 2. Wait until now_serving == my ticket
wait_turn:
    lw t3, 0(a3)
    bne t2, t3, wait_turn
    
    # CRITICAL SECTION
    lw t4, 0(a4)
    addi t4, t4, 1
    sw t4, 0(a4)
    
    # 3. Release Lock (now_serving++)
    lw t3, 0(a3)
    addi t3, t3, 1
    # Use.rl equivalent behavior to ensure data is flushed
    fence w, w
    sw t3, 0(a3)
    
    addi t0, t0, -1
    bnez t0, acquire_loop
    
    li t1, 2; sw t1, 0(a1)
    j finish

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 50
acquire_loop1:
    li t1, 1
    amoadd.w t2, t1, (a2)
wait_turn1:
    lw t3, 0(a3)
    bne t2, t3, wait_turn1
    
    # CRITICAL SECTION
    lw t4, 0(a4)
    addi t4, t4, 1
    sw t4, 0(a4)
    
    # Release Lock
    lw t3, 0(a3)
    addi t3, t3, 1
    fence w, w
    sw t3, 0(a3)
    
    addi t0, t0, -1
    bnez t0, acquire_loop1
    
    li t1, 2; sw t1, 4(a1)
    j finish

finish:
    csrr t0, mhartid
    bnez t0, pass_end
    
1:  lw t1, 4(a1)
    li t2, 2
    bne t1, t2, 1b
    
    lw t3, 0(a4)
    li t4, 100
    bne t3, t4, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
next_ticket:  .word 0
now_serving:  .word 0
shared_counter:.word 0
sync_flags:   .word 0, 0
system_stacks:.skip 2048
