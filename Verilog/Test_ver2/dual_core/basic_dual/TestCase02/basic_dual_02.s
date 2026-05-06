# Group: basic_dual | TestCase: 02 (TC22)
# Description: Stack Isolation
# Verifies that Core 0 and Core 1 have distinct, non-overlapping stack pointers.
.section.text
.global _start
_start:
    csrr t0, mhartid
    
    # Stack isolation: Each core gets 1024 bytes
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    # Push unique signature to stack
    li t3, 0xCAFEBABE
    add t3, t3, t0       # Core 0: CAFEBABE, Core 1: CAFEBABF
    addi sp, sp, -4
    sw t3, 0(sp)
    
    # Rendezvous Barrier
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

    # Pop and verify signature is intact (No cross-corruption)
    lw t6, 0(sp)
    addi sp, sp, 4
    
    li t3, 0xCAFEBABE
    add t3, t3, t0
    bne t6, t3, fail

pass_end:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak

.section.data
.align 4
sync_flags:   .word 0x0, 0x0
system_stacks:.skip 2048
