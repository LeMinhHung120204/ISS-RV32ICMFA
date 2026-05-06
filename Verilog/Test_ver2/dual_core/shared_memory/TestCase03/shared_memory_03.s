# Group: shared_memory | TestCase: 03 (TC63)
# Description: False_Share_0 (Basic False Sharing)
# Core 0 writes offset 0, Core 1 writes offset 4 of the SAME 64-byte cache line.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, false_share_block
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 500
2:  lw t3, 0(a2)         # Access offset 0
    addi t3, t3, 1
    sw t3, 0(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 500
2:  lw t3, 4(a2)         # Access offset 4 (same cache line)
    addi t3, t3, 1
    sw t3, 4(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 4(a1)
    
    # Wait for Core 0 and check
3:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 3b
    
    lw t4, 4(a2)
    li t5, 500           # Verify no updates were lost due to bus storm
    bne t4, t5, fail
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6                 # Align to 64-byte boundary
false_share_block:
   .word 0              # Offset 0 (Core 0)
   .word 0              # Offset 4 (Core 1)
   .space 56            # Rest of the cache line
sync_flags:.word 0, 0
system_stacks:.skip 2048
