# Group: benchmark | TestCase: 01
# Description: Memory Copy & Zero-Length Corner Case
# Tests sequential byte loads/stores, loop boundaries, and zero-length handling.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la a0, dst_str
    la a1, src_str
    li a2, 10            # Length to copy

    # Corner case: Check if length is zero before starting
    beqz a2, check       

copy_loop:
    lb t0, 0(a1)         
    sb t0, 0(a0)         
    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a2, -1
    bnez a2, copy_loop

check:
    la a0, dst_str
    lb t1, 0(a0)         # First byte should be 'R' (0x52)
    li t2, 0x52
    bne t1, t2, fail
    
    lb t1, 4(a0)         # Fifth byte should be '-' (0x2D)
    li t2, 0x2D
    bne t1, t2, fail

pass:
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
src_str:.asciz "RISC-V_TEST"
dst_str:.space 20
