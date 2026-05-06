# Group: shared_memory | TestCase: 08 (TC68)
# Description: Cross_Cache Line Access
# Reading/Writing exactly on the boundary of two adjacent 64B cache lines.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flags
    la a2, boundary_mem
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1; sw t1, 0(a1)
1:  lw t2, 4(a1); beqz t2, 1b

    li t0, 200
2:  # Write word at offset 60 (end of line 1)
    li t1, 0x11111111
    sw t1, 60(a2)
    # Write word at offset 64 (start of line 2)
    li t2, 0x22222222
    sw t2, 64(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2; sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1; sw t1, 4(a1)
1:  lw t2, 0(a1); beqz t2, 1b

    li t0, 200
2:  # Read from boundary locations and stress the memory prefetcher
    lw t1, 60(a2)
    lw t2, 64(a2)
    addi t0, t0, -1
    bnez t0, 2b
    
    # Final check
    li t3, 0x11111111
    bne t1, t3, fail
    li t4, 0x22222222
    bne t2, t4, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
boundary_mem:.space 128 # Two 64B lines
sync_flags:  .word 0, 0
system_stacks:.skip 2048
