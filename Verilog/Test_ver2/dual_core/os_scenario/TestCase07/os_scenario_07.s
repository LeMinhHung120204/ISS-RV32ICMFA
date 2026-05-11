# Group: os_scenario | TestCase: 07 (TC97)
# Description: Context Save
# Simulates an OS interrupt entry routine that saves core registers to the stack.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core
    
    la sp, system_stacks + 1024
    la t0, trap_handler
    csrw mtvec, t0
    
    # Load dummy values
    li x5, 0x55555555
    li x6, 0x66666666
    
    ecall
    
    # Verify values were saved on stack by trap handler
    lw t1, -4(sp)
    li t2, 0x55555555
    bne t1, t2, fail
    
    lw t1, -8(sp)
    li t2, 0x66666666
    bne t1, t2, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

trap_handler:
    # Save partial context (x5, x6)
    addi sp, sp, -8
    sw x5, 4(sp)
    sw x6, 0(sp)
    addi sp, sp, 8   # Restore sp for test purposes
    
    csrr t5, mepc
    addi t5, t5, 4
    csrw mepc, t5
    mret

park_core: wfi; j park_core

.section.data
system_stacks:.skip 2048
