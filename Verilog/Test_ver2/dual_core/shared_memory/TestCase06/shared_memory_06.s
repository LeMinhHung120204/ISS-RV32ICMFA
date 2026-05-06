# Group: shared_memory | TestCase: 06 (TC66)
# Description: Token_Pass
# Cores pass a write-token in a circle to take turns updating a shared memory location.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, token_flag
    la a2, shared_data
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t0, 5             # Passes token 5 times
1:  lw t1, 0(a1)
    bnez t1, 1b          # Wait until token == 0
    
    # Critical section
    lw t2, 0(a2)
    addi t2, t2, 10
    sw t2, 0(a2)
    
    # Pass token to Core 1
    li t1, 1
    fence w, w
    sw t1, 0(a1)
    
    addi t0, t0, -1
    bnez t0, 1b
    
    # Check final value when done
2:  lw t1, 0(a1)
    li t2, 2
    bne t1, t2, 2b       # Wait for Core 1 to signal completely done
    
    lw t3, 0(a2)
    li t4, 100           # (10 + 10) * 5 = 100
    bne t3, t4, fail
    j pass_end

core1_main:
    li t0, 5
1:  lw t1, 0(a1)
    li t2, 1
    bne t1, t2, 1b       # Wait until token == 1
    
    # Critical section
    lw t2, 0(a2)
    addi t2, t2, 10
    sw t2, 0(a2)
    
    # Pass token to Core 0
    fence w, w
    sw zero, 0(a1)
    
    addi t0, t0, -1
    bnez t0, 1b
    
    # Signal completely done
    li t1, 2
    sw t1, 0(a1)
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
token_flag: .word 0     # 0 = Core 0 turn, 1 = Core 1 turn
shared_data:.word 0
system_stacks:.skip 2048
