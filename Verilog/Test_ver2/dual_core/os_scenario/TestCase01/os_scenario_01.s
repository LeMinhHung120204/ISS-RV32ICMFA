# Group: os_scenario | TestCase: 01 (TC91)
# Description: IPI_Soft_Int (Inter-Processor Interrupt)
# Core 0 configures CLINT to send an MSIP (Software Interrupt) to Core 1.
.section.text
.global _start
_start:
    csrr t0, mhartid
    li t1, 1024
    mul t2, t0, t1
    la sp, system_stacks + 1024
    add sp, sp, t2
    
    la a1, sync_flags
    
    beqz t0, core0_main
    li t1, 1
    beq t0, t1, core1_main
    j park_core

core0_main:
    # Wait for Core 1 to set up its trap handler
1:  lw t2, 4(a1)
    beqz t2, 1b

    # Send IPI to Core 1: write 1 to MSIP for Hart 1 (CLINT base + 4)
    li t3, 0x02000004
    li t4, 1
    sw t4, 0(t3)

    # Wait for Core 1 to process interrupt and set flag to 2
1:  lw t2, 4(a1)
    li t3, 2
    bne t2, t3, 1b
    j pass_end

core1_main:
    # Setup Trap Handler
    la t0, trap_handler_c1
    csrw mtvec, t0
    
    # Enable MSIE (bit 3) in mie
    li t0, 8
    csrs mie, t0
    
    # Enable MIE (bit 3) in mstatus
    csrs mstatus, t0
    
    # Signal Core 0 that we are ready
    li t1, 1
    sw t1, 4(a1)
    
    # Wait in a loop until trap modifies the flag
1:  lw t2, 4(a1)
    li t3, 2
    bne t2, t3, 1b
    j pass_end

trap_handler_c1:
    # Trap entered! Clear MSIP for Hart 1 to acknowledge
    li t3, 0x02000004
    sw zero, 0(t3)
    
    # Update sync flag to 2
    la t3, sync_flags
    li t4, 2
    sw t4, 4(t3)
    
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
.align 4
sync_flags:.word 0, 0
system_stacks:.skip 2048
