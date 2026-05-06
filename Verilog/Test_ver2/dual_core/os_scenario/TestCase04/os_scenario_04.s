# Group: os_scenario | TestCase: 04 (TC94)
# Description: Misaligned Memory Access Exception
# Triggers an exception by loading from an unaligned memory address.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core
    
    la t0, trap_handler
    csrw mtvec, t0
    
    # Attempt misaligned load
    la t0, align_test
    addi t0, t0, 1      # Address not divisible by 4
    lw t1, 0(t0)        # Should trap
    
    la t0, trap_flag
    lw t1, 0(t0)
    li t2, 1
    bne t1, t2, fail
    j pass_end

trap_handler:
    # Check mcause == 4 (Load address misaligned)
    csrr t1, mcause
    li t2, 4
    bne t1, t2, fail
    
    la t3, trap_flag
    li t4, 1
    sw t4, 0(t3)
    
    csrr t5, mepc
    addi t5, t5, 4
    csrw mepc, t5
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
align_test:.word 0xDEADBEEF
trap_flag:.word 0
