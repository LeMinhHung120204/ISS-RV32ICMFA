# Group: synchronization | TestCase: 08 (TC58)
# Description: Fence_I (Instruction Fence / Self-Modifying Code)
# Writes a new instruction to memory, flushes I-Cache, and executes it.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core   # Only Core 0 runs this

    la a2, smc_target
    
    # Construct instruction: li t3, 0x99 (addi x28, x0, 0x99)
    # Binary: 0000 1001 1001 0000 0000 1110 0001 0011 = 0x09900E13
    li t1, 0x09900E13
    sw t1, 0(a2)         # Overwrite the 'li t3, 0x0' instruction
    
    # Must flush Instruction Cache pipeline so the newly written code is fetched
    fence.i
    
smc_target:
    li t3, 0x0           # This will be OVERWRITTEN by the li t3, 0x99
    
    # Verify execution of the modified instruction
    li t4, 0x99
    bne t3, t4, fail

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core
