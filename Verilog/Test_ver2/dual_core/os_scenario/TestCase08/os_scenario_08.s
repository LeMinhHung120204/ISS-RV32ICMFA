# Group: os_scenario | TestCase: 08 (TC98)
# Description: Context Restore
# Simulates an OS returning from an interrupt, restoring saved context.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core
    
    la sp, system_stacks + 1024
    la t0, trap_handler
    csrw mtvec, t0
    
    # Pre-load stack with expected values
    li t1, 0xAAAAAAAA
    sw t1, -4(sp)
    li t1, 0xBBBBBBBB
    sw t1, -8(sp)
    
    # Corrupt registers
    li x5, 0
    li x6, 0
    
    ecall
    
    # Verify registers were restored
    li t1, 0xAAAAAAAA
    bne x5, t1, fail
    li t1, 0xBBBBBBBB
    bne x6, t1, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

trap_handler:
    # Restore context (x5, x6) from stack
    lw x5, -4(sp)
    lw x6, -8(sp)
    
    csrr t5, mepc
    addi t5, t5, 4
    csrw mepc, t5
    mret

park_core: wfi; j park_core

.section.data
system_stacks:.skip 2048
