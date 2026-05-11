# Group: os_scenario | TestCase: 03 (TC93)
# Description: Illegal Instruction Exception
# Executes an invalid opcode and verifies the trap handler sets mcause correctly.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core
    
    la t0, trap_handler
    csrw mtvec, t0
    
    # Execute illegal instruction
   .word 0x00000000
    
    # We should return here safely
    la t0, trap_flag
    lw t1, 0(t0)
    li t2, 1
    bne t1, t2, fail
    j pass_end

trap_handler:
    # Check mcause == 2 (Illegal Instruction)
    csrr t1, mcause
    li t2, 2
    bne t1, t2, fail
    
    # Set flag
    la t3, trap_flag
    li t4, 1
    sw t4, 0(t3)
    
    # Advance mepc by 4 to skip the illegal instruction
    csrr t5, mepc
    addi t5, t5, 4
    csrw mepc, t5
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
trap_flag:.word 0
