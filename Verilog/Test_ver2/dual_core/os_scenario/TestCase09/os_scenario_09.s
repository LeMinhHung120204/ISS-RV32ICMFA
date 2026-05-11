# Group: os_scenario | TestCase: 09 (TC99)
# Description: Interrupt Masking (MIE=0)
# Core 1 clears global interrupts. Core 0 sends IPI. Core 1 must ignore it.
.section.text
.global _start
_start:
    csrr t0, mhartid
    la sp, system_stacks + 1024
    li t1, 1024
    mul t1, t0, t1
    add sp, sp, t1
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
1:  lw t2, 4(a1)
    beqz t2, 1b

    # Send IPI
    li t3, 0x02000004
    li t4, 1
    sw t4, 0(t3)

    # Let Core 1 spin for a while
    li t5, 1000
2:  addi t5, t5, -1
    bnez t5, 2b
    
    # Signal test over
    li t4, 2
    sw t4, 0(a1)
    j pass_end

core1_main:
    la t0, trap_handler
    csrw mtvec, t0
    
    # Disable MIE (bit 3) in mstatus!
    li t0, 8
    csrc mstatus, t0
    
    # Enable MSIE (bit 3) in mie
    csrs mie, t0
    
    li t1, 1; sw t1, 4(a1)
    
    # Spin until Core 0 says test is over
1:  lw t2, 0(a1)
    li t3, 2
    bne t2, t3, 1b
    
    # If we get here and trap_flag is 0, MIE successfully masked the interrupt
    la t4, trap_flag
    lw t5, 0(t4)
    bnez t5, fail
    j pass_end

trap_handler:
    # We should NEVER enter here because MIE=0
    la t0, trap_flag
    li t1, 1
    sw t1, 0(t0)
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
trap_flag:.word 0
sync_flags:.word 0, 0
system_stacks:.skip 2048
