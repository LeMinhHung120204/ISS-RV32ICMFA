# Group: os_scenario | TestCase: 02 (TC92)
# Description: Timer Interrupt
# Programs the CLINT mtimecmp register to trigger a timer interrupt in the future.
.section.text
.global _start
_start:
    csrr t0, mhartid
    bnez t0, park_core

    la sp, system_stacks + 1024
    
    # Setup Trap Handler
    la t0, trap_handler
    csrw mtvec, t0
    
    # Read mtime (0x0200BFF8)
    li t0, 0x0200BFF8
    lw t1, 0(t0)      # mtime low
    lw t2, 4(t0)      # mtime high
    
    # Add offset to mtime to fire interrupt in the near future
    li t3, 500
    add t1, t1, t3
    
    # Write to mtimecmp for Hart 0 (0x02004000)
    li t0, 0x02004000
    sw t2, 4(t0)      # Write high first to prevent accidental early trigger
    sw t1, 0(t0)      # Write low
    
    # Enable MTIE (bit 7) in mie
    li t4, 128
    csrs mie, t4
    
    # Enable MIE (bit 3) in mstatus
    li t4, 8
    csrs mstatus, t4

    # Infinite loop waiting for interrupt
1:  la t5, trap_flag
    lw t6, 0(t5)
    beqz t6, 1b
    
    j pass_end

trap_handler:
    # Timer trap occurred!
    # Disable MTIE to prevent infinite traps
    li t4, 128
    csrc mie, t4
    
    # Set flag
    la t5, trap_flag
    li t6, 1
    sw t6, 0(t5)
    mret

pass_end: li a0, 0; ebreak
fail: li a0, 1; ebreak
park_core: wfi; j park_core

.section.data
trap_flag:.word 0
system_stacks:.skip 2048
