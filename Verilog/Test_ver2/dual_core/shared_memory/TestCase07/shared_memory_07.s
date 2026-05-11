# Group: shared_memory | TestCase: 07 (TC67)
# Description: Bulk_Move
# Core 0 writes a large array, issues fence, then flags Core 1. Core 1 validates.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024; mul t1, t0, t1; add sp, sp, t1
    la a1, sync_flag
    la a2, bulk_data
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t0, 32            # Write 32 words
    li t1, 1             # Value to write
    mv a3, a2
1:  sw t1, 0(a3)
    addi a3, a3, 4
    addi t1, t1, 1
    addi t0, t0, -1
    bnez t0, 1b
    
    fence w, w           # Ensure bulk data is visible
    li t2, 1
    sw t2, 0(a1)         # Signal Core 1
    j pass_end

core1_main:
1:  lw t2, 0(a1)
    beqz t2, 1b          # Wait for Core 0
    
    fence r, r           # Ensure reads happen after flag check
    li t0, 32
    li t1, 1
    mv a3, a2
2:  lw t3, 0(a3)
    bne t3, t1, fail     # Data integrity check
    addi a3, a3, 4
    addi t1, t1, 1
    addi t0, t0, -1
    bnez t0, 2b

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 6
sync_flag:.word 0
.align 6
bulk_data:.space 128    # 32 words
system_stacks:.skip 2048
