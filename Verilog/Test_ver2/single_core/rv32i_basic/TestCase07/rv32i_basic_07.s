# Group: rv32i_basic | TestCase: 07
# Description: Control Hazard (Miss) & Signed vs Unsigned Comparisons
# Tests fall-through behavior using edge cases of signed/unsigned logic.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    li t1, -1            # 0xFFFFFFFF
    li t2, 1             # 0x00000001
    
    # Corner cases: Signed vs Unsigned
    bge t1, t2, fail     # Signed: -1 is NOT >= 1 (Fall-through)
    bltu t1, t2, fail    # Unsigned: 0xFFFFFFFF is NOT < 1 (Fall-through)
    beq t1, t2, fail     # Not equal (Fall-through)

pass:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak
park_core:
    wfi
    j park_core
