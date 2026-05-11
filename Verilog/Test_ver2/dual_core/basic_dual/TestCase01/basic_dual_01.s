# Group: basic_dual | TestCase: 01 (TC21)
# Description: Boot_mhartid
# Both cores read their mhartid and write it to their specific memory location.
.section.text
.global _start
_start:
    csrr t0, mhartid
    
    # Calculate address: core_id_flags + (mhartid * 4)
    la t1, core_id_flags
    slli t2, t0, 2
    add t1, t1, t2
    
    # Store hart ID to memory
    sw t0, 0(t1)
    
    # Wait for both to finish (Rendezvous)
    la a1, sync_flags
    li t1, 1
    slli t2, t0, 2
    add t3, a1, t2
    sw t1, 0(t3)        # Write 1 to own sync flag
    
    xori t4, t0, 1      # Get other core's ID (0->1, 1->0)
    slli t4, t4, 2
    add t4, a1, t4
1:  lw t5, 0(t4)
    bne t5, t1, 1b      # Spin until other core sets its flag

    # Verification by Core 0
    bnez t0, pass_end
    
    la t1, core_id_flags
    lw t2, 0(t1)        # Core 0 ID should be 0
    bnez t2, fail
    lw t2, 4(t1)        # Core 1 ID should be 1
    li t3, 1
    bne t2, t3, fail

pass_end:
    li a0, 0
    ebreak
fail:
    li a0, 1
    ebreak

.section.data
.align 4
core_id_flags:.word 0xFF, 0xFF
sync_flags:   .word 0x0, 0x0
