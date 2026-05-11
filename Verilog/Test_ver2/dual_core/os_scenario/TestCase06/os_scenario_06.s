# Group: os_scenario | TestCase: 06 (TC96)
# Description: CSR Privilege Violation
# Attempting to write to a read-only CSR (mvendorid) should raise an exception.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core
    
    la t0, trap_handler
    csrw mtvec, t0
    
    # mvendorid (0xF11) is Read-Only. Writing to it must trap.
    li t1, 0x1
    csrw mvendorid, t1
    
    la t0, trap_flag
    lw t1, 0(t0)
    li t2, 1
    bne t1, t2, fail
    j pass_end

trap_handler:
    # mcause == 2 (Illegal instruction)
    csrr t1, mcause
    li t2, 2
    bne t1, t2, fail
    
    la t3, trap_flag
    li t4, 1
    sw t4, 0(t3)
    
    csrr t5, mepc
    addi t5, t5, 4
    csrw mepc, t5
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
trap_flag:.word 0
