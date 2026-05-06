# Group: rv32i_basic | TestCase: 09
# Description: WAW Hazard (Write-After-Write) & Memory Overwrite
# Tests out-of-order writeback prevention when ALU overwrites a slow Load.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la t0, test_data
    lw t1, 0(t0)               # Slow load writes to t1 (0xBAD)
    lui t1, 0x12345            # Fast ALU immediately overwrites t1
    
    # WAW Hazard: t1 MUST hold 0x12345000 at the end. 
    # If WB stage is not ordered, the slow load might overwrite it with 0xBAD.
    lui t2, 0x12345
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
test_data:
   .word 0x00000BAD
