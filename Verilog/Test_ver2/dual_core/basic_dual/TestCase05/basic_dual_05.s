# Group: basic_dual | TestCase: 05 (TC25)
# Description: IPI Wakeup (Software Interrupt)
# Core 0 wakes up Core 1 from WFI using CLINT memory-mapped registers.
.section.text
.global _start
_start:
    csrr t0, mhartid
    beqz t0, core0_main

core1_main:
    la a0, trap_handler
    csrw mtvec, a0      # Set trap vector
    
    li a1, 8
    csrs mstatus, a1    # Enable MIE (Machine Interrupt Enable)
    csrs mie, a1        # Enable MSIE (Machine Software Interrupt Enable)

    la a1, sync_flags
    li t1, 1
    sw t1, 4(a1)        # Signal ready to sleep

    wfi                 # Go to sleep

    # Should wake up here after trap return
    la a1, sync_flags
    lw t2, 8(a1)        # Check if trap handler set the wake flag
    beqz t2, fail
    j pass_end

core0_main:
    la a1, sync_flags
1:  lw t2, 4(a1)
    beqz t2, 1b         # Wait for Core 1 to be ready

    # Write to CLINT MSIP of Core 1 (Base address 0x02000000 + 4)
    li t3, 0x02000004
    li t4, 1
    sw t4, 0(t3)        # Trigger Software Interrupt on Core 1

    # Wait for Core 1 to wake up and finish
    li t3, 1000
2:  addi t3, t3, -1
    bnez t3, 2b
    j pass_end

trap_handler:
    # We reached the trap handler!
    la a1, sync_flags
    li t1, 1
    sw t1, 8(a1)        # Set wake flag
    
    # Clear the interrupt (Write 0 to MSIP)
    li t3, 0x02000004
    sw zero, 0(t3)
    
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

.section.data
.align 4
sync_flags:.word 0, 0, 0
