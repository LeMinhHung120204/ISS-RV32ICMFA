# Group: basic_dual | TestCase: 03 (TC23)
# Description: Independent Loop
# Cores execute independent mathematical loops to ensure no pipeline cross-talk.
.section.text
.global _start
_start:
    csrr t0, mhartid
    
    # Stack isolation
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    beqz t0, core0_loop
    j core1_loop

core0_loop:
    # Sum 1 to 10
    li t1, 10
    li t2, 0
1:  add t2, t2, t1
    addi t1, t1, -1
    bnez t1, 1b
    # Store result
    la t3, results
    sw t2, 0(t3)
    j sync_end

core1_loop:
    # Sum 1 to 20
    li t1, 20
    li t2, 0
1:  add t2, t2, t1
    addi t1, t1, -1
    bnez t1, 1b
    # Store result
    la t3, results
    sw t2, 4(t3)
    j sync_end

sync_end:
    # Rendezvous
    la a1, sync_flags
    li t1, 1
    slli t2, t0, 2
    add t3, a1, t2
    sw t1, 0(t3)
    xori t4, t0, 1
    slli t4, t4, 2
    add t4, a1, t4
1:  lw t5, 0(t4)
    beqz t5, 1b

    # Verify
    bnez t0, pass_end
    la t3, results
    lw t4, 0(t3)
    li t5, 55           # Sum 1..10 = 55
    bne t4, t5, fail
    lw t4, 4(t3)
    li t5, 210          # Sum 1..20 = 210
    bne t4, t5, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

.section.data
.align 4
results:      .word 0, 0
sync_flags:   .word 0x0, 0x0
system_stacks:.skip 2048
