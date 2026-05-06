# Group: atomic | TestCase: 10 (TC40)
# Description: Misaligned AMO Exception
# Verifies that AMO on a non-word-aligned address correctly raises an exception.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    # Setup Trap Handler
    la t0, trap_handler
    csrw mtvec, t0

    la a0, test_data
    addi a0, a0, 1       # Create misaligned address (not a multiple of 4)
    
    # This must cause a Trap!
    amoadd.w zero, zero, (a0)
    
    # If it reaches here, the CPU failed to generate an exception
    j fail

trap_handler:
    # Exception caught successfully!
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
test_data:    .word 0x0
system_stacks:.skip 2048
