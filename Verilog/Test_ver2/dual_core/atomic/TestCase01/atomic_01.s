# Group: atomic | TestCase: 01 (TC31)
# Description: AMOADD.W Contention
# Both cores simultaneously add to a shared counter. Checks Bus Arbiter fairness.
.section.text
.global _start
_start:
    csrr t0, mhartid
    
    # Stack isolation: 1024 bytes per core
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    la a0, shared_counter
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
park_core:
    wfi
    j park_core

core0_main:
    # Rendezvous barrier: Core 0 ready
    li t1, 1
    sw t1, 0(a1)
1:  lw t2, 4(a1)
    beqz t2, 1b

    # Atomic Add 100 times
    li t0, 100
    li t1, 1
2:  amoadd.w zero, t1, (a0)
    addi t0, t0, -1
    bnez t0, 2b
    j wait_end

core1_main:
    # Rendezvous barrier: Core 1 ready
    li t1, 1
    sw t1, 4(a1)
1:  lw t2, 0(a1)
    beqz t2, 1b

    # Atomic Add 100 times
    li t0, 100
    li t1, 1
2:  amoadd.w zero, t1, (a0)
    addi t0, t0, -1
    bnez t0, 2b
    j wait_end

wait_end:
    # Barrier 2: Wait for both to finish AMO operations
    csrr t0, mhartid
    li t1, 2
    slli t2, t0, 2
    add t3, a1, t2
    sw t1, 0(t3)        # Write 2 to own sync flag
    
    # Wait for the other core's flag to become 2
    xori t4, t0, 1      # Get other core's ID (0->1, 1->0)
    slli t4, t4, 2
    add t4, a1, t4
3:  lw t5, 0(t4)
    bne t5, t1, 3b

    # Core 0 checks the final result (100 + 100 = 200)
    bnez t0, pass_end
    
    lw t1, 0(a0)
    li t2, 200
    bne t1, t2, fail

pass_end:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak

.section.data
.align 4
shared_counter:.word 0x0
sync_flags:    .word 0x0, 0x0
system_stacks: .skip 2048
