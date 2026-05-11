# Group: basic_dual | TestCase: 07 (TC27)
# Description: 2-Way Ping Pong Handshake
# Core 0 and Core 1 alternate setting flags to synchronize execution.
.section.text
.global _start
_start:
    csrr t0, mhartid
    beqz t0, core0_main

core1_main:
    la a1, sync_flags
1:  lw t2, 0(a1)        # Wait for Ping (Core 0 sets Flag 0)
    beqz t2, 1b
    
    li t1, 1
    sw t1, 4(a1)        # Send Pong (Core 1 sets Flag 1)
    j pass_end

core0_main:
    la a1, sync_flags
    li t1, 1
    sw t1, 0(a1)        # Send Ping
    
1:  lw t2, 4(a1)        # Wait for Pong
    beqz t2, 1b
    j pass_end

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak

.section.data
.align 4
sync_flags:.word 0x0, 0x0
