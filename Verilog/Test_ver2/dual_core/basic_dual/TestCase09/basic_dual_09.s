# Group: basic_dual | TestCase: 09 (TC29)
# Description: Simultaneous ECALL Trap
# Both cores trigger an environment call and handle the trap independently.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la t1, trap_handler
    csrw mtvec, t1      # Set trap handler

    la a1, sync_flags
    
    # Trigger ECALL
    ecall

    # Execution should return here if mret was successful
    # Verify flag was set by trap handler
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
    sw t4, 0(t3)        # Set my flag
    
    csrr t5, mepc
    addi t5, t5, 4      # Skip the ecall instruction
    csrw mepc, t5
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

.section.data
.align 4
sync_flags:.word 0x0, 0x0
