# Group: rv32i_basic | TestCase: 06
# Description: Control Hazard (Taken) & Backward Branching Boundary
# Tests pipeline flushing with nested forward and backward jumps.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    li t1, 1
    beq t1, t1, forward_jump   # Always taken (flush IF/ID)
    
    # MUST BE FLUSHED
    li t2, 0xBAD         
    j fail

backward_jump:
    # Arrived from forward_jump
    li t4, 2
    beq t1, t4, fail           # 1!= 2
    j pass                     # Done

forward_jump:
    li t1, 2                   # Change condition
    j backward_jump            # Backward jump (flush again)
    
    # MUST BE FLUSHED
    li t2, 0xBAD
    j fail

pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
