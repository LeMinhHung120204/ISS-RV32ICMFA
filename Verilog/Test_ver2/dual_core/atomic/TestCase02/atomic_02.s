# Group: atomic | TestCase: 02 (TC32)
# Description: AMOSWAP.W Atomicity
# Core 0 constantly swaps. Core 1 reads to ensure no torn values are visible.
.section.text
.global _start
_start:
    csrr t0, mhartid
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    la a0, shared_val
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    li t1, 1
    sw t1, 0(a1)
1:  lw t2, 4(a1)
    beqz t2, 1b

    li t0, 500
    li t1, 0xAAAAAAAA
    li t2, 0x55555555
2:  amoswap.w zero, t1, (a0)
    amoswap.w zero, t2, (a0)
    addi t0, t0, -1
    bnez t0, 2b
    
    li t1, 2
    sw t1, 0(a1)
    j pass_end

core1_main:
    li t1, 1
    sw t1, 4(a1)
1:  lw t2, 0(a1)
    beqz t2, 1b

2:  lw t3, 0(a0)
    # Check if value is either all 0s, AAs or 55s
    beqz t3, 3f
    li t4, 0xAAAAAAAA
    beq t3, t4, 3f
    li t4, 0x55555555
    beq t3, t4, 3f
    j fail               # Torn read detected (Atomicity broken!)
3:  lw t2, 0(a1)
    li t4, 2
    bne t2, t4, 2b       # Loop until Core 0 finishes
    
pass_end:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core: 
    wfi
    j park_core

.section.data
.align 4
shared_val:   .word 0x0
sync_flags:   .word 0x0, 0x0
system_stacks:.skip 2048
