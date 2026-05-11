# Group: basic_dual | TestCase: 10 (TC30)
# Description: Simultaneous EBREAK
# Both cores trigger an environment break (debugger) trap independently.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la t1, trap_handler
    csrw mtvec, t1

    la a1, sync_flags
    
    # Trigger EBREAK
    ebreak

    # Verification
    slli t2, t0, 2
    add t3, a1, t2
    lw t4, 0(t3)
    beqz t4, fail
    j pass_end

trap_handler:
    csrr t0, mhartid
    la a1, sync_flags
    slli t2, t0, 2
    add t3, a1, t2
    li t4, 1
    sw t4, 0(t3)
    
    csrr t5, mepc
    addi t5, t5, 4      # Skip ebreak instruction
    csrw mepc, t5
    mret

pass_end: li a0, 0; ebreak  # Ebreak again to stop simulator!
fail: li a0, 1; ebreak

.section.data
.align 4
sync_flags:.word 0x0, 0x0
