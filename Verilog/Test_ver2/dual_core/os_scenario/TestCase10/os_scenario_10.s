# Group: os_scenario | TestCase: 10 (TC100)
# Description: Nested Trap
# Triggers an exception from WITHIN a trap handler to test mepc/mstatus backup.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core
    
    la t0, trap_handler
    csrw mtvec, t0
    
    # Initialize depth counter
    la t0, trap_depth
    sw zero, 0(t0)
    
    ecall   # First trap
    
    # Verify depth became 2
    la t0, trap_depth
    lw t1, 0(t0)
    li t2, 2
    bne t1, t2, fail
    j pass_end

trap_handler:
    la t0, trap_depth
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    
    li t2, 1
    beq t1, t2, first_trap
    
    # --- SECOND TRAP (Illegal Instr) ---
    csrr t0, mepc
    addi t0, t0, 4 # Skip illegal instr
    csrw mepc, t0
    mret
    
first_trap:
    # --- FIRST TRAP (ECALL) ---
    # MUST save MEPC and MSTATUS, otherwise nested trap destroys them
    csrr s0, mepc
    csrr s1, mstatus
    
    # Trigger nested exception
   .word 0x00000000
    
    # Restore MEPC and MSTATUS
    csrw mepc, s0
    csrw mstatus, s1
    
    # Advance original MEPC to skip ECALL
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
trap_depth:.word 0
