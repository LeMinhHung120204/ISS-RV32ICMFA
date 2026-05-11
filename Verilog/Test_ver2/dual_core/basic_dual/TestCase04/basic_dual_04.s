# Group: basic_dual | TestCase: 04 (TC24)
# Description: WFI Sleep Mode
# Core 1 goes into Wait For Interrupt (WFI) sleep mode while Core 0 continues.
.section.text
.global _start
_start:
    csrr t0, mhartid
    beqz t0, core0_main

core1_main:
    # Signal that Core 1 is about to sleep
    la a1, sync_flags
    li t1, 1
    sw t1, 4(a1)
sleep_loop:
    wfi                 # Go to sleep
    j sleep_loop        # Should not wake up in this test

core0_main:
    la a1, sync_flags
    # Wait for Core 1 to signal it's sleeping
1:  lw t2, 4(a1)
    beqz t2, 1b
    
    # Do some dummy work to ensure Core 0 runs fine while Core 1 sleeps
    li t3, 100
2:  addi t3, t3, -1
    bnez t3, 2b

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

.section.data
.align 4
sync_flags:.word 0x0, 0x0
